require_relative 'consul'
require_relative 'primitive'
require 'chef/mash'

module Choregraphie
  class ConsulMaintenance < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:reason] ||= 'Maintenance for Chef Choregraphie'

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
      checks = Diplomat::Agent.checks()
      maint_status = checks.dig(@maintenance_key, 'Status')
      maint_status == 'critical' && checks.dig(@maintenance_key, 'Notes')
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
        if (maint_notes = maintenance?)
          Chef::Log.warn "Consul maintenance was already enabled (reason: #{maint_notes})."
        else
          maintenance(true)
        end
      end

      choregraphie.cleanup do
        require 'diplomat'
        if (maint_notes = maintenance?)
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
