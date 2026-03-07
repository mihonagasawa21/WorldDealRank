# frozen_string_literal: true

require "faraday"
require "json"
require "date"

module Fx
  class FrankfurterFetcher
    def initialize
      @conn = Faraday.new(url: "https://api.frankfurter.app") do |f|
        f.options.open_timeout = 10
        f.options.timeout = 60
        f.headers["User-Agent"] = "rate_match"
        f.adapter Faraday.default_adapter
      end
    end

    def refresh_all
      codes = Country.where.not(currency_code: [nil, ""])
        .distinct
        .pluck(:currency_code)
        .map { |x| x.to_s.strip.upcase }
        .reject { |x| x.empty? || x == "USD" }
        .uniq

      return if codes.empty?

      result = fetch_rates(codes)
      fx_date = result[:fx_date]
      rates = result[:rates]

      return if rates.empty?

      Country.where(currency_code: rates.keys).find_each do |c|
        rate = rates[c.currency_code.to_s.upcase]
        next if rate.nil?

        c.update!(
          fx_rate_usd: rate,
          fx_date: fx_date,
          last_error: nil
        )
      rescue StandardError => e
        c.update!(last_error: "FX失敗: #{e.class} #{e.message}")
      end
    end

    def fetch_rates(currency_codes)
      codes = Array(currency_codes).map { |x| x.to_s.strip.upcase }.reject(&:empty?).uniq
      codes = codes.reject { |x| x == "USD" }

      return { fx_date: nil, rates: {} } if codes.empty?

      rates = {}
      fx_date = nil

      codes.each_slice(20) do |slice|
        resp = @conn.get("/latest", { from: "USD", to: slice.join(",") })
        return { fx_date: nil, rates: {} } unless resp.status.to_i == 200

        body = JSON.parse(resp.body.to_s)
        date_s = body["date"].to_s
        fx_date ||= (date_s.empty? ? nil : Date.parse(date_s))

        r = body["rates"]
        if r.is_a?(Hash)
          r.each do |k, v|
            next if v.nil?
            rates[k.to_s.upcase] = v.to_d
          end
        end
      rescue StandardError
        return { fx_date: nil, rates: {} }
      end

      { fx_date: fx_date, rates: rates }
    end
  end
end
