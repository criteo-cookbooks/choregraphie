require_relative 'primitive'

module Choregraphie
  class CheckFile < Primitive
    def initialize(file_path, options = {})
      @file_path = file_path
      @period    = options[:period] || 5
    end

    def register(choregraphie)

      choregraphie.before do
        Chef::Log.info "Waiting for #{@file_path} presence"
        sleep(@period) until ::File.exists?(@file_path)
      end

      choregraphie.cleanup do
        ::FileUtils.rm(@file_path) if File.exists?(@file_path)
      end
    end
  end
end
