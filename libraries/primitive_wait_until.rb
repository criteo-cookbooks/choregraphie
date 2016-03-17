require_relative 'primitive'
require 'mixlib/shellout'

# This primitive takes a block, a mixlib::shellout or a command (as a string)
# it will execute the command/block/shellout until it returns true (exits with 0 for commands). Any other value or StandardException will be interpretation as a failure of the condition
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
      Proc.new do
        cmd.run_command
        cmd.error!
        true
      end
    end

    def register(choregraphie)
      choregraphie.before do
        while true
          result = (@condition.call == true) rescue false
          break if result
          Chef::Log.info "Waiting for #{@name} to be true"
          sleep(@period)
        end
      end
    end
  end
end
