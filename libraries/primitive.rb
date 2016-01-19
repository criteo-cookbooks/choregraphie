require_relative './choregraphie'
module Choregraphie
  class Primitive
    def register(choregraphie)
      raise NotImplementedError, "You must implement :register method"
    end

    def self.inherited(klass)
      DSL.register_primitive(klass)
    end

  end
end

module Choregraphie
  class CheckFile < Primitive
    def initialize(file_path)
      @file_path = file_path
    end

    def register(choregraphie)

      choregraphie.before do
        Chef::Log.info "Waiting for #{@file_path} presence"
        sleep(5) until ::File.exists?(@file_path)
      end

      choregraphie.after do
        ::FileUtils.rm(@file_path)
      end
    end
  end
end
