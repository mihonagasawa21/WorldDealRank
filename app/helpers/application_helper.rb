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

  def safe_photo_url(country_or_url)
    raw =
      if country_or_url.respond_to?(:photo_url)
        country_or_url.photo_url
      else
        country_or_url
      end

    url = raw.to_s.strip
    return "" if url.empty?

    if url.start_with?("//")
      url = "https:#{url}"
    elsif url.start_with?("http://")
      url = url.sub(/\Ahttp:\/\//, "https://")
    end

    ERB::Util.html_escape(url)
  end

    ERB::Util.html_escape(url)
  end
end