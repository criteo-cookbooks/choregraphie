require_relative 'choregraphie'

module Choregraphie

  class Primitive
    @@primitives    = []

    def register(choregraphie)
      raise NotImplementedError, "You must implement :register method"
    end

    def self.all
      @@primitives
    end

    def self.inherited(klass)
      @@primitives << klass

      # can be defined in any primitive by: "primitive_name :my_name"
      # default to the name of the class
      # the name will be used in a choregraphie block
      klass.define_singleton_method(:primitive_name) do |name=nil|
        @name = name.to_sym if name
        @name
      end
      name = klass.to_s.split('::').last.gsub(/(.)([A-Z]+)/,'\1_\2').downcase.to_sym
      klass.primitive_name name
    end
  end
end
