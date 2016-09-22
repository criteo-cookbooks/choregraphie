require_relative 'primitive'
require 'chef/mash'
require 'json'

# This primitive is based on optimistic concurrency (using compare-and-swap) rather than consul sessions.
# It allows to support the unavailability of the local consul agent (for reboot, reinstall, ...)
module Choregraphie
  class ConsulLock < Primitive
    def initialize(options = {}, &block)
      @options = Mash.new(options)

      # path in consul (name_of_the_lock)
      validate!(:path, String)
      # id of this node
      validate!(:id, String)
      # max number of node holding the lock
      @options[:concurrency] ||= 1

      @options[:backoff] ||= 5 # seconds

      if @options[:consul_token]
        require 'diplomat'
        Diplomat.configure do |config|
          config.acl_token = @options[:consul_token]
        end
      end

      # this block could be used to configure diplomat if needed
      yield if block_given?
    end

    def semaphore
      # this object cannot be reused after enter/exit
      Semaphore.get_or_create(path, @options[:concurrency])
    end

    def backoff
      Chef::Log.warn "Will sleep #{@options[:backoff]}"
      sleep @options[:backoff]
      false # indicates failure
    end

    def wait_until(action, opts = {})
      Chef::Log.info "Will #{action} the lock #{path}"
      success = 0.upto(opts[:max_failures] || Float::INFINITY).any? do |tries|
        begin
          yield || backoff
        rescue => e
          Chef::Log.warn "Error while #{action}-ing lock"
          Chef::Log.warn e
          backoff
        end
      end

      if success
        Chef::Log.info "#{action.to_s.capitalize}ed the lock #{path}"
      else
        Chef::Log.warn "Will ignore errors and since we've reached #{opts[:max_failures]} errors"
      end

    end

    def register(choregraphie)

      choregraphie.before do
        wait_until(:enter) { semaphore.enter(@options[:id]) }
      end

      choregraphie.cleanup do
        # hack: We can ignore failure there since it is only to release
        # the lock. If there is a temporary failure, we can wait for the
        # next run to release the lock without compromising safety.
        # The reason we have to be a bit more relaxed here, is that all
        # chef run including a choregraphie with this primitive try to
        # release the lock at the end of a successful run
        wait_until(:exit, max_failures: 5) { semaphore.exit(@options[:id]) }
      end
    end

    private

    def path
      @options[:path]
    end

    def validate!(name, klass)
      raise ArgumentError, "Missing #{name}" unless @options.has_key?(name)
      raise ArgumentError, "Invalid #{name} (must be a #{klass})" unless @options[name].is_a?(klass)
    end

  end

  class Semaphore

    def self.get_or_create(path, concurrency)
      require 'diplomat'
      retry_left = 5
      value =  Mash.new({ version: 1, concurrency: concurrency, holders: {} })
      current_lock = begin
                       Chef::Log.info "Fetch lock state for #{path}"
                       Diplomat::Kv.get(path, decode_values: true)
                     rescue Diplomat::KeyNotFound
                       Chef::Log.info "Lock for #{path} did not exist, creating with value #{value}"
                       Diplomat::Kv.put(path, value.to_json, cas: 0) # we ignore success/failure of CaS
                       (retry_left -= 1) > 0 ? retry : raise
                     end.first
      desired_lock = bootstrap_lock(value, current_lock)
      Semaphore.new(path, desired_lock)
    end

    def self.bootstrap_lock(desired_value, current_lock)
      desired_lock = current_lock.dup
      desired_value = desired_value.dup
      current_holders = Mash.new(JSON.parse(current_lock['Value'])['holders'])
      desired_value['holders'] = current_holders
      desired_lock['Value'] = desired_value.to_json
      desired_lock
    end

    def initialize(path, new_lock)
      @path = path
      @h    = JSON.parse(new_lock['Value'])
      @cas  = new_lock['ModifyIndex']
    end

    def enter(name)
      return true if holders.has_key?(name.to_s) # lock is re-entrant
      if holders.size < concurrency
        holders[name.to_s] ||= Time.now
        result = Diplomat::Kv.put(@path, to_json, cas: @cas)
        Chef::Log.debug("Someone updated the lock at the same time, will retry") unless result
        result
      else
        Chef::Log.debug("Too many lock holders (concurrency:#{concurrency})")
        false
      end
    end

    def exit(name)
      if holders.delete(name.to_s)
        result = Diplomat::Kv.put(@path, to_json, cas: @cas)
        Chef::Log.debug("Someone updated the lock at the same time, will retry") unless result
        result
      else
        true
      end
    end

    private

    def to_json
      @h.to_json
    end

    def concurrency
      @h['concurrency']
    end

    def holders
      @h['holders']
    end
  end
end
