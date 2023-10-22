require_relative 'consul'
require_relative 'primitive'
require 'chef/mash'
require 'chef/application'

module Choregraphie
  class ConsulHealthCheck < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:tries] ||= 10
      @options[:delay] ||= 15

      raise ArgumentError, 'Missing/Empty checkids/services options. You must provide at least one' unless @options[:checkids]&.any? || @options[:services]&.any?

      ConsulCommon.setup_consul(@options)

      yield if block_given?
    end

    # @return [Array<String>] name of the failing checks
    def failing_checks(tries)
      non_passing = []
      require 'diplomat'
      tries.times do |try|
        Kernel.sleep @options[:delay]
        begin
          #  We wrap this inside a begin..rescue block
          # so that any consul failure would not instantly
          # result in an exception
          checks = Diplomat::Check.checks(@options)
        rescue StandardError => e
          Chef::Log.error "Could not get checks from Consul: #{e}"
          next
        end

        relevant_checks = checks.select do |id, check|
          @options[:checkids]&.include?(id) || @options[:services]&.include?(check['ServiceName'])
        end.values

        @options[:checkids]&.each do |check_id|
          raise "Check #{check_id} is not registered" unless checks.key?(check_id)
        end

        non_passing = relevant_checks
                      .reject { |check| check['Status'] == 'passing' }

        Chef::Log.warn "Check #{non_passing.map { |c| c['CheckID'] }.join(',')} failed" if non_passing.any?

        return [] if non_passing.empty?

        Chef::Log.warn "Some checks did not pass, will retry #{tries - try} more times"
      end
      non_passing.map { |check| "#{check['ServiceName']}/#{check['CheckID']}" }
    end

    def register(choregraphie)
      choregraphie.cleanup do
        failing_checks = failing_checks(@options[:tries])
        raise "Failed to pass Consul checks: #{failing_checks.join(', ')}" unless failing_checks.empty?
      end
    end
  end
end
