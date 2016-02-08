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
      @after  = []

      # read all available primitives and make them available with a method
      # using their name. It allows to call `check_file '/tmp/titi'` to
      # instanciate the CheckFile primitive
      Primitive.all.each do |klass|
        instance_eval <<-EOM
        def #{klass.primitive_name}(*args)
          primitive = ::#{klass}.new(*args)
          primitive.register(self)
        end
        EOM
      end

      # this + method_missing allows to access method defined outside of the
      # block (in the recipe context for instance)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    def method_missing(method, *args, &block)
      @self_before_instance_eval.send method, *args, &block
    end

    def after_block_name(resource_name)
      "After callbacks for #{@name}/#{resource_name}"
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

    def after(&block)
      if block
        Chef::Log.debug("Registering an after block for #{@name}")
        @after << block
      end
      @after
    end

    # Ensure resource exists and its provider supports whyrun
    def self.ensure_whyrun_supported(run_context, resource_name)
      resource = run_context.resource_collection.find(resource_name)
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


    def on(event)
      Chef::Log.warn("Registering on #{event} for #{@name}")
      case event
      when String # resource name
        resource_name = event
        before_events = before
        after_events  = after

        Chef.event_handler do
          on :converge_start do |run_context|
            Choregraphie.ensure_whyrun_supported(run_context, resource_name)
          end
        end

        ruby_block before_block_name(event) do
          block do
            Chef::Log.debug "Resource #{resource_name} will converge"
            before_events.each { |b| b.call(resource_name) }
          end
          action :nothing
          subscribes :create, event, :before
        end
        ruby_block after_block_name(event) do
          block do
            Chef::Log.debug "Resource #{resource_name} has converged"
            before_events.each { |b| b.call(resource_name) }
          end
          action :nothing
          subscribes :create, event, :immediately
        end
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
