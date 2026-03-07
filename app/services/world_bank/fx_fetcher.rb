# frozen_string_literal: true

module WorldBank
  class FxFetcher
    INDICATOR = "PA.NUS.FCRF"

    def initialize
      @fetcher = WorldBank::IndicatorFetcher.new(INDICATOR)
    end

    def fill_missing_fx_all
      Country.where(fx_rate_usd: nil).where.not(iso3: [nil, ""]).find_each do |country|
        fill_one(country)
      end
    end

    def fill_one(country)
      res = @fetcher.latest_value(country.iso3)
      return false if res[:value].nil?

      # 年次データなので fx_date は年だけ保存できないなら nil のままでもOK
      country.update(fx_rate_usd: res[:value], last_error: nil)
      true
    rescue StandardError
      false
    end
  end
end
