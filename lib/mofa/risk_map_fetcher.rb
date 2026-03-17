def filter_by_safety(list, safety)
  list.select do |c|
    min = c.safety_min_level
    max = c.safety_max_level

    no_safety_data = min.nil? && (max.nil? || max.to_i <= 0)

    case safety.to_s
    when "none"
      no_safety_data
    when "lv1"
      next false if no_safety_data

      if min.nil?
        max.to_i <= 1
      else
        min.to_i <= 1
      end
    else
      true
    end
  end
end

def safety_text(country)
  max = country.safety_max_level.to_i
  return "危険情報なし" if max <= 0

  min = country.safety_min_level
  return "要確認" if min.nil?

  min.to_i.to_s
end

def safety_style(country)
  min = country.safety_min_level
  max = country.safety_max_level.to_i

  base = "padding:2px 6px;display:inline-block;font-weight:800;border-radius:0;"
  return base + "background:#e9eefb;" if max <= 0
  return base + "background:#fff1c9;" if min.nil?

  case min.to_i
  when 0 then base + "background:#e9eefb;"
  when 1 then base + "background:#dff5e6;"
  when 2 then base + "background:#ffe08a;"
  else        base + "background:#ffd0d0;"
  end
end

def warn_text(country)
  max = country.safety_max_level.to_i
  return "" if max <= 0

  min = country.safety_min_level
  return "注：一部地域で最大危険レベル#{max}です" if min.nil?

  min_i = min.to_i
  return "" if max <= min_i

  "注：一部地域で最大危険レベル#{max}です"
end