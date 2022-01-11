module Choregraphie
  module DSL
    # DSL helper
    def choregraphie(name)
      Choregraphie.add(Choregraphie.new(name) { 'empty proc' })
    end
  end
end
