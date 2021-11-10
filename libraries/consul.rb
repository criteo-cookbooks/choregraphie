require_relative 'primitive'

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
          config.acl_token = @options[:consul_token]
        end
      else
        options[:token] = options[:consul_token]
      end
    end
  end
end
