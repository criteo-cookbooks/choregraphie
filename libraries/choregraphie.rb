require 'chef/event_dispatch/dsl'
require_relative 'dsl'
require 'chef/recipe'
require 'chef/resource'
require 'chef/provider'

module Choregraphie
  class Choregraphie

    @@choregraphies = {}

    def self.all
      @@choregraphies.values
    end

    def self.add(choregraphie)
      raise "Choregraphie #{choregraphie.name} is already defined" if @@choregraphies[choregraphie.name]

      @@choregraphies[choregraphie.name] = choregraphie
    end

    attr_reader :name
    attr_reader :resources

    def clean_name
      name.gsub(/[^a-z]+/, '_')
    end

    def initialize(name, &block)
      @name = name
      # Contains the list of resources protected by this choregraphie
      @resources = []
      @before = []
      @cleanup = []
      @finish = []

      # read all available primitives and make them available with a method
      # using their name. It allows to call `check_file '/tmp/titi'` to
      # instantiate the CheckFile primitive
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
      finish_events = finish

      Chef.event_handler do
        # Using converge_complete instead of run_completed bk reboot
        # resources do not make the run fail
        # and we don't want to cleanup just before the reboot
        on :converge_complete do
          Chef::Log.debug "Chef-client convergence successful, will clean up all primitives"
          cleanup_events.each { |b| b.call }
          finish_events.each { |b| b.call }
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
      "Cleanup callbacks for #{name}/#{resource_name}"
    end
    def before_block_name(resource_name)
      "Before callbacks for #{name}/#{resource_name}"
    end
    def finish_block_name(resource_name)
      "Terminate callbacks for #{name}/#{resource_name}"
    end

    def before(&block)
      if block
        Chef::Log.debug("Registering a before block for #{name}")
        @before << block
      end
      @before
    end

    def cleanup(&block)
      if block
        Chef::Log.debug("Registering an cleanup block for #{name}")
        @cleanup << block
      end
      @cleanup
    end

    def finish(&block)
      if block
        Chef::Log.debug("Registering a finish block for #{name}")
        raise " A finish block already registered" unless @finish.empty?
        @finish << block
      end
      @finish
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
      resources << resource_name

      # catch before in the closure
      before_events = method(:before)

      Chef.event_handler do
        on :converge_start do |run_context|
          Choregraphie.ensure_whyrun_supported(run_context, resource_name, opts['ignore_missing_resource'])
        end
      end

      ruby_block before_block_name(resource_name) do
        block do
          Chef::Log.info "Resource #{resource_name} will converge, running before callbacks"
          before_events.call.each { |b| b.call(resource_name) }
        end
        action :nothing
        subscribes :create, resource_name, :before
      end
    end


    def on(event, opts = {})
      opts = Mash.new(opts)
      Chef::Log.info("Registering on #{event} for #{name}")
      case event
      when String # resource name
        resource_name = event

        setup_hook(resource_name, opts)
      when Regexp
        on_each_resource do |resource, choregraphie|
          next unless resource.to_s =~ event
          Chef::Log.debug "Will create a dynamic recipe for #{resource}"
          Chef::Recipe.new(:choregraphie, "dynamic_recipe_for_#{resource.to_s}_#{clean_name}", run_context).instance_eval do
            choregraphie.setup_hook(resource.to_s, opts)
          end
        end
      when :weighted_resources
        # all resources whose weight is non-zero is protected by default
        weight_threshold = opts[:threshold] || 0
        on_each_resource do |resource, choregraphie|
          if resource.class.properties.has_key?(:weight)
            next if resource.weight <= weight_threshold
            Chef::Log.debug "Will create a dynamic recipe for #{resource}"
            Chef::Recipe.new(:choregraphie, "dynamic_recipe_for_#{resource.to_s}_#{clean_name}", run_context).instance_eval do
              choregraphie.setup_hook(resource.to_s, opts)
            end
          else
            raise "Resource #{resource} does not respond to :weight method. There is most likely a bug in resource-weight cookbook"
          end
        end
      when :converge_start
        before_events = method(:before)
        Chef.event_handler do
          on :converge_start do
            Chef::Log.info "Chef client starting to converge, running before callbacks."
            before_events.call.each { |b| b.call }
          end
        end
      else
        # TODO
        raise "Symbol types are not yet supported"
      end
    end

    private

    def on_each_resource
      myself = self
      Chef.event_handler do
        on :converge_start do |run_context|
          run_context.resource_collection.each do |resource|
            yield resource, myself
          end
        end
      end
    end

  end
end

Chef::Recipe.send(:include, Choregraphie::DSL)
Chef::Resource.send(:include, Choregraphie::DSL)
Chef::Provider.send(:include, Choregraphie::DSL)
