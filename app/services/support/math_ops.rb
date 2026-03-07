require "bigdecimal"
require "bigdecimal/util"

module Support
  module MathOps
    MUL = "\u002a"

    def self.mul(a, b)
      a.to_d.public_send(MUL, b.to_d)
    end

    def self.div(a, b)
      x = a.to_d
      y = b.to_d
      return BigDecimal("0") if y == 0
      x / y
    end
  end
end
