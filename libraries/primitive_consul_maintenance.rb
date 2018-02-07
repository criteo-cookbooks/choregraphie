require_relative 'primitive'
require 'chef/mash'

module Choregraphie
  class ConsulMaintenance < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      @options[:reason] ||= 'Maintenance for Chef Choregraphie'

      if @options[:consul_token]
        require 'diplomat'
        Diplomat.configure do |config|
          config.acl_token = @options[:consul_token]
        end
      end

      # this block could be used to configure diplomat if needed
      yield if block_given?
    end

    def maintenance?
      checks = Diplomat::Agent.checks()
      maint_status = checks.dig('_node_maintenance', 'Status')
      maint_status == 'critical' && checks.dig('_node_maintenance', 'Notes')
    end

    def register(choregraphie)
      choregraphie.before do
        require 'diplomat'
        if (maint_notes = maintenance?)
          Chef::Log.warn "Consul maintenance was already enabled (reason: #{maint_notes})."
        else
          Diplomat::Maintenance.enable(true, @options[:reason])
        end
      end

      choregraphie.cleanup do
        require 'diplomat'
        if (maint_notes = maintenance?)
          if maint_notes == @options[:reason]
            Chef::Log.info "Consul maintenance will be disabled (reason: #{maint_notes})."
            Diplomat::Maintenance.enable(false, @options[:reason])
          else
            Chef::Log.warn "Consul maintenance was enabled by something other than this choregraphie (reason: #{maint_notes}, expected_reason: #{@options[:reason]}). So we won't disable it."
          end
        end
      end
    end
  end
end
