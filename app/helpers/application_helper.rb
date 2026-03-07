module ApplicationHelper
  include IconHelper
  def flag_twemoji_url(iso2)
    code = iso2.to_s.strip.upcase
    return "" unless code.match?(/\A[A-Z]{2}\z/)

    a = 0x1F1E6 + (code.getbyte(0) - 65)
    b = 0x1F1E6 + (code.getbyte(1) - 65)
    hex = [a, b].map { |cp| cp.to_s(16) }.join("-")

    "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/svg/#{hex}.svg"
  end

  def top10_card_class(i)
    return "top10-card--big" if i <= 2
    "top10-card--wide"
  end

  def top10_photo_style(country)
    url = country.photo_url.to_s.strip
    return "background:#ffffff80;" if url.empty?
    "background-image:url('#{ERB::Util.html_escape(url)}');"
  end
end