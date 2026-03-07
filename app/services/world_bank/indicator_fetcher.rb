# frozen_string_literal: true

require "json"

module WorldBank
  class IndicatorFetcher
    def initialize(indicator)
      @indicator = indicator
      @conn = WorldBank::Client.connection
    end

    def latest_value(iso3)
      code = iso3.to_s.strip.upcase
      return { value: nil, year: nil } if code.empty?

      resp = @conn.get(
        "/v2/country/#{code}/indicator/#{@indicator}",
        { format: "json", per_page: 60 }
      )

      return { value: nil, year: nil } unless resp.success?

      data = JSON.parse(resp.body.to_s)
      list = data.is_a?(Array) ? data[1] : nil
      return { value: nil, year: nil } unless list.is_a?(Array)

      row = list.find { |r| r.is_a?(Hash) && r["value"].present? }
      return { value: nil, year: nil } if row.nil?

      { value: row["value"].to_d, year: row["date"].to_i }
    rescue StandardError
      { value: nil, year: nil }
    end
  end
end
