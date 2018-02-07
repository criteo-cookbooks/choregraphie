require_relative 'primitive'
require 'mixlib/shellout'

# This primitive takes a block, a mixlib::shellout or a command (as a string).
# It will execute the command/block/shellout until it returns true (exits with
# 0 for commands). Any other value or StandardException will be interpretated
# as a failure of the condition
module Choregraphie
  class WaitUntil < Primitive
    # Two ways to create this primitive:
    # - "condition, options" where condition is either a shellout or a string
    # - "options, block"
    def initialize(*args, &block)
      condition = block_given? ? block : args.shift
      options = Mash.new(args.shift || {})
      @period = options['period'] || 5
      @name   = options['name']
      @when   = options['when'] || 'before'

      # Store the condition as a block
      case condition
      when Mixlib::ShellOut
        @condition = wrap_shellout(condition)
        @name    ||= condition.cmd
      when String
        cmd        = Mixlib::ShellOut.new(condition, logger: Chef::Log)
        @condition = wrap_shellout(cmd)
        @name    ||= condition
      when Proc
        @condition = condition
        @name    ||= condition.to_s
      else
        raise "#{condition.class} is not supported"
      end
    end

    def wrap_shellout(cmd)
      proc do |resource_name|
        cmd.environment['RESOURCE_NAME'] = resource_name
        cmd.run_command
        !cmd.error?
      end
    end

    def register(choregraphie)
      unless %w(before cleanup).include?(@when.to_s)
        raise "Incorrect value <#{@when}> for 'when' option in wait_until"
      end
      choregraphie.send(@when.to_sym) do |resource_name|
        loop do
          Chef::Log.info "Checking if #{@name} is 'true'"
          result = begin
                     @condition.call(resource_name)
                   rescue => e
                     Chef::Log.info "wait_until condition raised an exception: #{e.message}"
                     Chef::Log.info e.backtrace
                     raise
                   end
          break if result
          Chef::Log.info "Waiting #{@period}s before retrying"
          sleep(@period)
        end
      end
    end
  end
end
