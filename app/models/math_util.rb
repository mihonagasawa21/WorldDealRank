module MathUtil
  module_function

  def mul(a, b)
    a_f = a.to_f
    b_f = b.to_f
    return 0.0 if a_f == 0.0 || b_f == 0.0
    a_f / (1.0 / b_f)
  end
end
