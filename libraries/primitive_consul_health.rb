require_relative 'primitive'
require 'chef/mash'

module Choregraphie
  class ConsulHealthCheck < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:tries] ||= 10
      @options[:delay] ||= 15

      if @options[:consul_token]
        require 'diplomat'
        Diplomat.configure do |config|
          config.acl_token = @options[:consul_token]
        end
      end

      yield if block_given?
    end

    def are_checks_passing?(tries)
      require 'diplomat'
      tries.times do |try|
        Kernel::sleep @options[:delay]
        checks = Diplomat::Check.checks

        non_passing = @options[:checkids]
          .select { |id| checks[id]['CheckID'] }
          .reject { |id| checks[id]['Status'] == 'passing' }
          .tap { |id| Chef::Log.warn "Check #{id} failed" }

        return true if non_passing.empty?

        Chef::Log.warn "Some checks did not pass, will retry #{tries-try} more times"
      end
      false
    end

    def register(choregraphie)
      choregraphie.cleanup do
        Chef::Application.fatal!("Failed to pass Consul checks") unless are_checks_passing? @options[:tries]
      end
    end
  end
end
