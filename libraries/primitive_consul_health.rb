require_relative 'primitive'
require 'chef/mash'
require 'chef/application'

module Choregraphie
  class ConsulHealthCheck < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:tries] ||= 10
      @options[:delay] ||= 15

      raise ArgumentError, 'Missing checkids option' unless @options[:checkids]
      raise ArgumentError, 'Empty checkids option' if @options[:checkids].empty?

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
        Kernel.sleep @options[:delay]
        begin
          # We wrap this inside a begin..rescue block
          # so that any consul failure would not instantly
          # result in an exception
          checks = Diplomat::Check.checks
        rescue => e
          Chef::Log.error "Could not get checks from Consul: #{e}"
          next
        end

        non_passing = @options[:checkids]
          .select { |id| checks[id]['CheckID'] }
          .reject { |id| checks[id]['Status'] == 'passing' }
          .tap { |id| Chef::Log.warn "Check #{id} failed" }

        return true if non_passing.empty?

        Chef::Log.warn "Some checks did not pass, will retry #{tries - try} more times"
      end
      false
    end

    def register(choregraphie)
      choregraphie.cleanup do
        raise 'Failed to pass Consul checks' unless are_checks_passing? @options[:tries]
      end
    end
  end
end
