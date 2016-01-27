module Choregraphie
  module DSL
    @@choregraphies = []

    # DSL helper
    def choregraphie(name)
      @@choregraphies << Choregraphie.new(name, &Proc.new)
    end
  end
end
