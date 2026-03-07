# frozen_string_literal: true

module WorldBank
  class PlrFetcher
    INDICATOR = "PA.NUS.PPPC.RF"

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
      return false if res[:value].nil?

      country.update(plr: res[:value], last_error: nil)
      true
    rescue StandardError
      false
    end
  end
end
