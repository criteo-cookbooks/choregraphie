require_relative 'primitive'

module Choregraphie
  class After < Primitive
    def initialize(&block)
      @block = block
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
      FileUtils.touch(inprogress_marker)
    end

    def set_not_in_progress
      FileUtils.rm(inprogress_marker)
    end

    def installed?
      File.exist?(install_marker)
    end

    def set_installed
      FileUtils.touch(install_marker)
    end

    private

    def inprogress_marker
      File.join(Chef::Config[:file_cache_path], "choregraphie-#{@choregraphie_name.gsub(/[^a-zA-Z0-9]/, '_')}-inprogress")
    end

    def install_marker
      File.join(Chef::Config[:file_cache_path], "choregraphie-#{@choregraphie_name.gsub(/[^a-zA-Z0-9]/, '_')}-installed")
    end
  end
end
