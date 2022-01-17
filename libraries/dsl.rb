module Choregraphie
  module DSL
    # DSL helper
    def choregraphie(name, &block)
      Choregraphie.add(Choregraphie.new(name, &block))
    end
  end
end
