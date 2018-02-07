require_relative 'primitive_consul_lock'

module Choregraphie
  # This primitive is based on optimistic concurrency (using compare-and-swap) rather than consul sessions.
  # It allows to support the unavailability of the local consul agent (for reboot, reinstall, ...)
  # It is based on the notion of rack: all nodes inside a rack can take the lock at the same time. We only
  # allow a given number of racks to take the lock at the same time.
  # Note: this lock does not guarantee that all nodes of a given rack will be done at the same time.
  class ConsulRackLock < ConsulLock
    def initialize(options = {}, &block)
      @options = Mash.new(options)
      validate!(:rack, String) # id of the rack
      raise ArgumentError, '`service` option is not supported for consul_rack_lock' if @options[:service]

      super
    end

    def register(choregraphie)
      choregraphie.before do
        wait_until(:enter) { semaphore.enter(name: @options[:rack], server: @options[:id]) }
      end

      choregraphie.finish do
        # HACK: We can ignore failure there since it is only to release
        # the lock. If there is a temporary failure, we can wait for the
        # next run to release the lock without compromising safety.
        # The reason we have to be a bit more relaxed here, is that all
        # chef run including a choregraphie with this primitive try to
        # release the lock at the end of a successful run
        wait_until(:exit, max_failures: 5) { semaphore.exit(name: @options[:rack], server: @options[:id]) }
      end
    end

    def semaphore_class
      SemaphoreByRack
    end
  end

  class SemaphoreByRack < Semaphore

    def already_entered?(opts)
      name, server = validate_and_split!(opts)
      super && holders[name.to_s].key?(server.to_s)
    end

    def can_enter_lock?(opts)
      name, _server = validate_and_split!(opts)

      # we can always enter if our rack has the lock
      return true if holders.key?(name.to_s)

      super # we can enter if our rack can enter the lock
    end

    def enter_lock(opts)
      name, server = validate_and_split!(opts)
      holders[name.to_s] ||= {}
      holders[name.to_s][server.to_s] ||= Time.now
    end

    def exit_lock(opts)
      name, server = validate_and_split!(opts)
      holders[name.to_s].delete(server.to_s)
      holders.delete(name.to_s) if holders[name.to_s].empty?
    end

    private

    def validate_and_split!(opts)
      raise 'Must have a :name entry filled with rack identifier' unless opts[:name] && !opts[:name].empty?
      raise 'Must have a :server entry filled with server identifier' unless opts[:server] && !opts[:server].empty?
      [opts[:name], opts[:server]]
    end
  end
end
