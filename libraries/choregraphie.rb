require 'chef/event_dispatch/dsl'
require_relative 'dsl'
require 'chef/recipe'
require 'chef/resource'
require 'chef/provider'

module Choregraphie
  class Choregraphie

    attr_reader :name

    def initialize(name, &block)
      @name = name
      @before = []
      @cleanup= []

      # read all available primitives and make them available with a method
      # using their name. It allows to call `check_file '/tmp/titi'` to
      # instanciate the CheckFile primitive
      Primitive.all.each do |klass|
        instance_eval <<-EOM
        def #{klass.primitive_name}(*args, &block)
          primitive = ::#{klass}.new(*args, &block)
          primitive.register(self)
        end
        EOM
      end

      # bind cleanup in local context to access it in event_handler
      cleanup_events = cleanup

      Chef.event_handler do
        # Using converge_complete instead of run_completed bk reboot
        # resources do not make the run fail
        # and we don't want to cleanup just before the reboot
        on :converge_complete do
          Chef::Log.debug "Chef-client convergence successful, will clean up all primitives"
          cleanup_events.each { |b| b.call }
        end
      end

      # this + method_missing allows to access method defined outside of the
      # block (in the recipe context for instance)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    def method_missing(method, *args, &block)
      @self_before_instance_eval.send method, *args, &block
    end

    def cleanup_block_name(resource_name)
      "Cleanup callbacks for #{@name}/#{resource_name}"
    end
    def before_block_name(resource_name)
      "Before callbacks for #{@name}/#{resource_name}"
    end

    def before(&block)
      if block
        Chef::Log.debug("Registering a before block for #{@name}")
        @before << block
      end
      @before
    end

    def cleanup(&block)
      if block
        Chef::Log.debug("Registering an cleanup block for #{@name}")
        @cleanup << block
      end
      @cleanup
    end

    # Ensure resource exists and its provider supports whyrun
    def self.ensure_whyrun_supported(run_context, resource_name, ignore_missing_resource)
      begin
      resource = run_context.resource_collection.find(resource_name)
      rescue Chef::Exceptions::ResourceNotFound
        if ignore_missing_resource
          # some resources are defined only when used
          # so we ignore them
          return
        else
          raise
        end
      end
      if resource
        resource.allowed_actions.
          reject { |a| a == :nothing }.
          each do |a|
            provider = resource.provider_for_action(a)
            unless provider.whyrun_supported?
              Chef::Log.warn "Resource providers must support whyrun in order to be used by choregraphie"
              Chef::Log.warn "If you are defining a custom resource see https://github.com/chef/chef/issues/4537 for a possible workaround"
              raise "Provider for #{a} on #{resource.to_s} must support whyrun"
            end
          end
      else
        Chef::Log.warn "#{resource_name} is not yet defined ?"
      end
    end

    def setup_hook(resource_name, opts)

      # catch before in the closure
      before_events = before

      Chef.event_handler do
        on :converge_start do |run_context|
          Choregraphie.ensure_whyrun_supported(run_context, resource_name, opts['ignore_missing_resource'])
        end
      end

      ruby_block before_block_name(resource_name) do
        block do
          Chef::Log.debug "Resource #{resource_name} will converge"
          before_events.each { |b| b.call(resource_name) }
        end
        action :nothing
        subscribes :create, resource_name, :before
      end
    end


    def on(event, opts = {})
      opts = Mash.new(opts)
      Chef::Log.warn("Registering on #{event} for #{@name}")
      case event
      when String # resource name
        resource_name = event

        setup_hook(resource_name, opts)
      when Regexp
        # list all resources already defined
        run_context.resource_collection.
          map(&:to_s).select { |resource_name| resource_name =~ event }.
          each { |resource_name| setup_hook(resource_name, opts) }

        # TODO find a way to get resources defined after choregraphie
      else
        #TODO
        raise "Symbol type is not yet supported"
      end
    end
  end
end

Chef::Recipe.send(:include, Choregraphie::DSL)
Chef::Resource.send(:include, Choregraphie::DSL)
Chef::Provider.send(:include, Choregraphie::DSL)
