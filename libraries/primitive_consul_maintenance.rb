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

    def register(choregraphie)

      choregraphie.before do
        require 'diplomat'
        Diplomat::Maintenance.enable(true, @options[:reason])
      end

      choregraphie.cleanup do
        require 'diplomat'
        # WARNING
        # This means that any chef run will disable the maintenance mode on the
        # node
        Diplomat::Maintenance.enable(false, @options[:reason])
      end
    end
  end
end
