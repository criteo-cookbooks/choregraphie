require_relative 'primitive'

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

      # this block could be used to configure diplomat if needed
      yield if block_given?
    end

    def semaphore
      # this object cannot be reused after enter/exit
      Semaphore.get_or_create(path, @options[:concurrency])
    end

    def wait_until(action)
      Chef::Log.info "Will #{action} the lock #{path}"
      loop do
        break if begin
          begin
            yield
          rescue => e
            Chef::Log.warn "Error while #{action}-ing lock"
            Chef::Log.warn e
            false
          end
        end
        Chef::Log.warn "Will sleep #{@options[:backoff]}"
        sleep @options[:backoff]
      end
      Chef::Log.info "#{action.to_s.capitalize}ed the lock #{path}"
    end

    def register(choregraphie)

      choregraphie.before do
        wait_until(:enter) { semaphore.enter(@options[:id]) }
      end

      choregraphie.cleanup do
        wait_until(:exit) { semaphore.exit(@options[:id]) }
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
      value = begin
                Diplomat::Kv.get(path, decode_values: true)
              rescue Diplomat::KeyNotFound
                initial =  { version: 1, concurrency: concurrency, holders: {} }.to_json
                Chef::Log.info "Lock for #{path} did not exist, creating with value #{initial}"
                Diplomat::Kv.put(path, initial, cas: 0) # we ignore success/failure of CaS
                (retry_left -= 1) > 0 ? retry : raise
              end.first
              Semaphore.new(path, value)
    end

    def initialize(path, value)
      @path = path
      @h    = JSON.parse(value['Value'])
      @cas  = value['ModifyIndex']
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
        Chef::Log.error("#{@options[:id]} was not holding the lock. This is very wrong or someone removed it from lock")
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
