module Choregraphie
  module DSL
    @@choregraphies = []
    @@primitives    = []

    # DSL helper
    def choregraphie(name)
      @@choregraphies << Choregraphie.new(name, &Proc.new)
    end

    def self.register_primitive(klass)
      @@primitives << klass
    end

    def self.primitives
      @@primitives
    end
  end
end
