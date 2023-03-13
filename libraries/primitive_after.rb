require_relative 'primitive'

module Choregraphie
  class After < Primitive
    def initialize(name, &block)
      @block = block
      @name = name
    end

    def register(choregraphie)
      @choregraphie_name = choregraphie.name

      choregraphie.before do
        set_in_progress
      end

      choregraphie.cleanup do
        if in_progress?
          @block.call
          set_not_in_progress
        elsif !installed? # we are after a reinstallation, we can't know if we were in a choregraphie or not, run the block just in case
          @block.call
        end
        set_installed
      end
    end

    def in_progress?
      File.exist?(inprogress_marker)
    end

    def set_in_progress
      FileUtils.touch(inprogress_marker) unless in_progress?
    end

    def set_not_in_progress
      FileUtils.rm(inprogress_marker)
    end

    def installed?
      File.exist?(install_marker)
    end

    def set_installed
      FileUtils.touch(install_marker) unless installed?
    end

    private

    def inprogress_marker
      File.join(Chef::Config[:file_cache_path], "#{marker_prefix}-inprogress")
    end

    def install_marker
      File.join(Chef::Config[:file_cache_path], "#{marker_prefix}-installed")
    end

    def marker_prefix
      "choregraphie-#{@choregraphie_name.gsub(/[^a-zA-Z0-9]/, '_')}-#{@name.gsub(/[^a-zA-Z0-9]/, '_')}"
    end
  end
end
