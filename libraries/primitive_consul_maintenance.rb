require_relative 'consul'
require_relative 'primitive'
require 'chef/mash'

module Choregraphie
  class ConsulMaintenance < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:reason] ||= 'Maintenance for Chef Choregraphie'
      @options[:check_interval] ||= 5

      ConsulCommon.setup_consul(@options)

      validate_optional!(:service_id, String) # id of the service to put in maintenance

      @maintenance_key = if @options.key?(:service_id)
                           "_service_maintenance:#{@options[:service_id]}"
                         else
                           '_node_maintenance'
                         end

      # this block could be used to configure diplomat if needed
      yield if block_given?
    end

    def maintenance?
      # we observed in very rare cases that maintenance status could be not up to date
      # for ~5s after a restart
      results = 3.times.map do
        checks = Diplomat::Agent.checks
        maint_status = checks.dig(@maintenance_key, 'Status')
        sleep(@options[:check_interval])
        maint_status == 'critical' && !checks.dig(@maintenance_key, 'Notes').nil?
      end
      raise "Several consecutive checks of maintenance status returned different results: #{results.join(', ')}" if results.uniq.size > 1

      results.first
    end

    # @return [String, nil] reason of the maintenance, if any. Nil otherwise
    def maintenance_reason
      checks = Diplomat::Agent.checks
      checks.dig(@maintenance_key, 'Notes')
    end

    def maintenance(enable = true) # rubocop:disable Style/OptionalBooleanParameter
      token = @options[:consul_token]
      if @options.key?(:service_id)
        Diplomat::Service.maintenance(@options[:service_id], { enable: enable, reason: @options[:reason], token: token })
      else
        Diplomat::Maintenance.enable(enable, @options[:reason], { token: token })
      end
    end

    def register(choregraphie)
      choregraphie.before do
        require 'diplomat'
        if maintenance?
          Chef::Log.warn "Consul maintenance was already enabled (reason: #{maintenance_reason})."
        else
          maintenance(true)
        end
      end

      choregraphie.cleanup do
        require 'diplomat'
        if maintenance?
          maint_notes = maintenance_reason
          if maint_notes == @options[:reason]
            Chef::Log.info "Consul maintenance will be disabled (reason: #{maint_notes})."
            maintenance(false)
          else
            Chef::Log.warn "Consul maintenance was enabled by something other than this choregraphie " \
            "(reason: #{maint_notes}, expected_reason: #{@options[:reason]}). So we won't disable it."
          end
        end
      end
    end
  end
end
