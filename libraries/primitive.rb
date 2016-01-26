require_relative './choregraphie'
module Choregraphie
  class Primitive
    def register(choregraphie)
      raise NotImplementedError, "You must implement :register method"
    end

    def self.inherited(klass)
      DSL.register_primitive(klass)

      # can be defined in any primitive by: "primitive_name :my_name"
      # default to the name of the class
      # the name will be used in a choregraphie block
      klass.define_singleton_method(:primitive_name) do |name=nil|
        @name = name.to_sym if name
        @name
      end
      name = klass.to_s.split('::').last.gsub(/(.)([A-Z])/,'\1_\2').downcase.to_sym
      klass.primitive_name name
    end
  end
end

module Choregraphie
  class CheckFile < Primitive
    def initialize(file_path, options)
      @file_path = file_path
      @period    = options[:period] || 5
    end

    def register(choregraphie)

      choregraphie.before do
        Chef::Log.info "Waiting for #{@file_path} presence"
        sleep(@period) until ::File.exists?(@file_path)
      end

      choregraphie.after do
        ::FileUtils.rm(@file_path)
      end
    end
  end
end
