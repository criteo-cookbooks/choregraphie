require_relative 'consul'
require_relative 'primitive'
require 'chef/mash'
require 'json'

# This primitive is based on optimistic concurrency (using compare-and-swap) rather than consul sessions.
# It allows to support the unavailability of the local consul agent (for reboot, reinstall, ...)
module Choregraphie
  class ConsulLock < Primitive
    def initialize(options = {})
      @options = Mash.new(options)

      # path in consul (name_of_the_lock)
      validate!(:path, String)
      # id of this node
      validate!(:id, String)

      raise ArgumentError, "You can't set both concurrency and service" if @options[:concurrency] && @options[:service]

      @options[:backoff] ||= 5 # seconds

      ConsulCommon.setup_consul(@options)

      # this block could be used to configure diplomat if needed
      yield if block_given?
    end

    def concurrency
      @concurrency ||= if @options[:service]
                         require 'diplomat'
                         opts = @options[:service][:options] || {}
                         opts[:dc] = @options[:datacenter] if @options[:datacenter]
                         opts[:token] = @options[:token] if @options[:token]
                         total = Diplomat::Service.get(
                           @options[:service][:name],
                           :all,
                           opts,
                         ).count
                         # TODO: check only passing instances
                         [1, (@options[:service][:concurrency_ratio] * total).to_i].max
                       elsif @options[:concurrency]
                         @options[:concurrency]
                       else
                         1
                       end
    end

    def semaphore_class
      Semaphore
    end

    def semaphore
      # this object cannot be reused after enter/exit
      semaphore_class.get_or_create(path, concurrency: concurrency, dc: @options[:datacenter], token: @options[:token])
    end

    def backoff(start_time, current_try)
      started = Time.now - start_time
      Chef::Log.warn "Will sleep #{@options[:backoff]} between failures, current_try: #{current_try}, started #{human_duration(started)} ago" if (current_try % 100).zero?
      sleep @options[:backoff]
      false # indicates failure
    end

    def human_duration(duration_in_secs)
      s = ''
      s += "#{duration_in_secs / 86_400} days, " if duration_in_secs > 86_400
      s += "#{'%02d' % (duration_in_secs % 86_400 / 3600)}h " if duration_in_secs > 3600
      s += "#{'%02d' % (duration_in_secs % 3600 / 60)}m " if duration_in_secs > 60
      s += "#{'%02d' % (duration_in_secs % 60)}s"
      s
    end

    def wait_until(action, opts = {})
      dc = "(in #{@options[:datacenter]})" if @options[:datacenter]
      Chef::Log.info "Will #{action} the lock #{path} #{dc}"
      start = Time.now
      success = 0.upto(opts[:max_failures] || Float::INFINITY).any? do |tries|
        yield(start, tries) || backoff(start, tries)
      rescue StandardError => e
        Chef::Log.warn "Error while #{action}-ing lock"
        Chef::Log.warn e
        backoff(start, tries)
      end

      if success
        Chef::Log.info "#{action.to_s.capitalize}ed the lock #{path}"
      else
        Chef::Log.warn "Will ignore errors and since we've reached #{opts[:max_failures]} errors"
      end
    end

    def register(choregraphie)
      choregraphie.before do
        wait_until(:enter) { semaphore.enter(name: @options[:id]) }
      end

      choregraphie.finish do
        # HACK: We can ignore failure there since it is only to release
        # the lock. If there is a temporary failure, we can wait for the
        # next run to release the lock without compromising safety.
        # The reason we have to be a bit more relaxed here, is that all
        # chef run including a choregraphie with this primitive try to
        # release the lock at the end of a successful run
        wait_until(:exit, max_failures: 5) { semaphore.exit(name: @options[:id]) }
      end
    end

    private

    def path
      @options[:path].sub(%r{^/}, '')
    end
  end

  class Semaphore
    def self.get_or_create(path, concurrency:, **kwargs)
      dc = kwargs[:dc]
      token = kwargs[:token]
      require 'diplomat'
      retry_left = 5
      value = Mash.new({ version: 1, concurrency: concurrency, holders: {} })
      current_lock = begin
        Chef::Log.info "Fetch lock state for #{path}"
        Diplomat::Kv.get(path, decode_values: true, dc: dc, token: dc)
      rescue Diplomat::KeyNotFound
        Chef::Log.info "Lock for #{path} did not exist, creating with value #{value}"
        Diplomat::Kv.put(path, value.to_json, cas: 0, dc: dc, token: token) # we ignore success/failure of CaS
        (retry_left -= 1).positive? ? retry : raise
      end.first
      desired_lock = bootstrap_lock(value, current_lock)
      new(path, new_lock: desired_lock, dc: dc, token: token)
    end

    def self.bootstrap_lock(desired_value, current_lock)
      desired_lock = current_lock.dup
      desired_value = desired_value.dup
      current_holders = Mash.new(JSON.parse(current_lock['Value'])['holders'])
      desired_value['holders'] = current_holders
      desired_lock['Value'] = desired_value.to_json
      desired_lock
    end

    def initialize(path, new_lock:, **kwargs)
      dc = kwargs[:dc]
      token = kwargs[:token]
      @path = path
      @h    = JSON.parse(new_lock['Value'])
      @cas  = new_lock['ModifyIndex']
      @dc   = dc
      @token = token
    end

    def already_entered?(opts)
      name = opts[:name] # this is the server id
      holders.key?(name.to_s) # lock is re-entrant
    end

    def can_enter_lock?(_opts)
      holders.size < concurrency
    end

    def enter_lock(opts)
      name = opts[:name] # this is the server id
      holders[name.to_s] ||= Time.now
    end

    def enter(opts)
      return true if already_entered?(opts)

      if can_enter_lock?(opts)
        enter_lock(opts)
        require 'diplomat'
        result = Diplomat::Kv.put(@path, to_json, cas: @cas, dc: @dc, token: @token)
        Chef::Log.debug('Someone updated the lock at the same time, will retry') unless result
        result
      else
        Chef::Log.debug("Too many lock holders (concurrency:#{concurrency})")
        false
      end
    end

    def exit_lock(opts)
      name = opts[:name] # this is the server id
      holders.delete(name.to_s)
    end

    def exit(opts)
      if already_entered?(opts)
        exit_lock(opts)
        require 'diplomat'
        result = Diplomat::Kv.put(@path, to_json, cas: @cas, dc: @dc, token: @token)
        Chef::Log.debug('Someone updated the lock at the same time, will retry') unless result
        result
      else
        true
      end
    end

    private

    def to_json(*_args)
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
