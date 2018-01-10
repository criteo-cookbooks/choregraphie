module Choregraphie
  module DSL

    # DSL helper
    def choregraphie(name)
      Choregraphie.add(Choregraphie.new(name, &Proc.new))
    end
  end
end
