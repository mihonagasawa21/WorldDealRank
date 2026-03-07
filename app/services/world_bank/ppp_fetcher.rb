# frozen_string_literal: true

module WorldBank
  class PppFetcher
    INDICATOR = "PA.NUS.PPP"

    def initialize
      @fetcher = WorldBank::IndicatorFetcher.new(INDICATOR)
    end

    def refresh_all
      Country.where.not(iso3: [nil, ""]).find_each do |country|
        fetch_and_save!(country)
      end
    end

    def fetch_and_save!(country)
      res = @fetcher.latest_value(country.iso3)
      if res[:value].nil?
        append_error(country, "PPP取得失敗: valueなし")
        return false
      end

      country.update(
        ppp_lcu_per_intl: res[:value],
        ppp_year: res[:year],
        last_error: nil
      )
      true
    rescue StandardError => e
      append_error(country, "PPP取得失敗: #{e.class} #{e.message}")
      false
    end

    private

    def append_error(country, msg)
      base = country.last_error.to_s.strip
      country.last_error = base.empty? ? msg : "#{base} / #{msg}"
      country.save(validate: false) rescue nil
    end
  end
end
