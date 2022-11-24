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

    def self.clear
      @@choregraphies.clear
    end

    attr_reader :name, :resources

    # @return [Array<Primitive>] the list of primitives registered by this choregraphie
    attr_reader :primitives

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
      # list of primitive used by this choregraphie
      @primitives = []

      # read all available primitives and make them available with a method
      # using their name. It allows to call `check_file '/tmp/titi'` to
      # instantiate the CheckFile primitive
      delegated_args = RUBY_VERSION.to_i < 3 ? '*args, &block' : '*args, **kwargs, &block'
      Primitive.all.each do |klass|
        instance_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{klass.primitive_name}(#{delegated_args})
          primitive = ::#{klass}.new(#{delegated_args})
          @primitives << primitive
          primitive.register(self)
        end
        METHOD
      end

      # bind cleanup in local context to access it in event_handler
      cleanup_events = cleanup
      finish_events = finish

      Chef.event_handler do
        # Using converge_complete instead of run_completed bk reboot
        # resources do not make the run fail
        # and we don't want to cleanup just before the reboot
        on :converge_complete do
          Chef::Log.debug 'Chef-client convergence successful, will clean up all primitives'
          cleanup_events.each(&:call)
          finish_events.each(&:call)
        end
      end

      # this + method_missing allows to access method defined outside of the
      # block (in the recipe context for instance)
      @self_before_instance_eval = eval 'self', block.binding, __FILE__, __LINE__
      instance_eval(&block)
    end

    if RUBY_VERSION.to_i < 3
      def method_missing(method, *args, &block) # rubocop:disable Style/MissingRespondToMissing
        @self_before_instance_eval.send method, *args, &block
      end
    else
      def method_missing(method, *args, **kwargs, &block) # rubocop:disable Style/MissingRespondToMissing
        @self_before_instance_eval.send method, *args, **kwargs, &block
      end
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
        raise ' A finish block already registered' unless @finish.empty?

        @finish << block
      end
      @finish
    end

    # Ensure resource exists and its provider supports whyrun
    def self.ensure_whyrun_supported(run_context, resource_name, ignore_missing_resource)
      begin
        resource = run_context.resource_collection.find(resource_name)
      rescue Chef::Exceptions::ResourceNotFound
        if ignore_missing_resource # rubocop:disable Style/GuardClause
          # some resources are defined only when used
          # so we ignore them
          return
        elsif resource_name =~ /,/
          Chef::Log.warn "#{resource_name} contains a comma which triggers " \
            "https://github.com/criteo-cookbooks/choregraphie/issues/43, we can't check if resource supports why run or not"
          resource = run_context.resource_collection.map(&:itself).find { |r| r.declared_key == resource_name }
          raise Chef::Exceptions::ResourceNotFound unless resource
        else
          raise
        end
      end
      if resource
        resource.allowed_actions
                .reject { |a| a == :nothing }
                .each do |a|
          provider = resource.provider_for_action(a)
          next if provider.whyrun_supported?

          Chef::Log.warn 'Resource providers must support whyrun in order to be used by choregraphie'
          Chef::Log.warn 'If you are defining a custom resource see https://github.com/chef/chef/issues/4537 for a possible workaround'
          raise "Provider for #{a} on #{resource.declared_key} must support whyrun"
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
          next unless resource.declared_key =~ event

          Chef::Log.debug "Will create a dynamic recipe for #{resource}"
          Chef::Recipe.new(:choregraphie, "dynamic_recipe_for_#{resource.declared_key}_#{clean_name}", run_context).instance_eval do
            choregraphie.setup_hook(resource.declared_key, opts)
          end
        end
      when :weighted_resources
        # all resources whose weight is non-zero is protected by default
        weight_threshold = opts[:threshold] || 0
        on_each_resource do |resource, choregraphie|
          if resource.class.properties.key?(:weight) # rubocop:disable Style/GuardClause
            next if resource.weight <= weight_threshold

            Chef::Log.debug "Will create a dynamic recipe for #{resource}"
            Chef::Recipe.new(:choregraphie, "dynamic_recipe_for_#{resource.declared_key}_#{clean_name}", run_context).instance_eval do
              choregraphie.setup_hook(resource.declared_key, opts)
            end
          else
            raise "Resource #{resource} does not respond to :weight method. There is most likely a bug in resource-weight cookbook"
          end
        end
      when :converge_start
        before_events = method(:before)
        Chef.event_handler do
          on :converge_start do
            Chef::Log.info 'Chef client starting to converge, running before callbacks.'
            before_events.call.each(&:call)
          end
        end
      else
        # TODO
        raise 'Symbol types are not yet supported'
      end
    end

    private

    def on_each_resource
      myself = self
      Chef.event_handler do
        on :converge_start do |run_context|
          # yielded block can (and will) modify the resource collection
          # (for instance by adding resources)
          collection_copy = run_context.resource_collection.map(&:itself)
          collection_copy.each do |resource|
            yield resource, myself
          end
        end
      end
    end
  end
end

Chef::Recipe.include Choregraphie::DSL
Chef::Resource.include Choregraphie::DSL
Chef::Provider.include Choregraphie::DSL
