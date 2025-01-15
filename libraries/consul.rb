require_relative 'primitive'
require 'ostruct' # This is a Diplomat dependency that they never specified ...

# Common functions for Consul
module Choregraphie
  class ConsulCommon
    # Common setup
    def self.setup_consul(options)
      require 'diplomat'
      require 'diplomat/version'
      return unless options[:consul_token]

      if Diplomat::VERSION < '2.1.0'
        Diplomat.configure do |config|
          config.acl_token = options[:consul_token]
        end
      else
        options[:token] = options[:consul_token]
      end
    end

    def self.update_backup_url(consul_backup_url: nil)
      require 'diplomat'
      return if consul_backup_url.nil?

      Diplomat.configure do |config|
        config.url = consul_backup_url
      end
    end

    def self.reset_url
      require 'diplomat'
      Diplomat.configure do |config|
        config.url = Diplomat::Configuration.parse_consul_addr
      end
    end
  end
end
