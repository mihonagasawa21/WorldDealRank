# frozen_string_literal: true

require "net/http"
require "json"

module Fx
  class CurrencyConverter
    ENDPOINT = "https://api.frankfurter.app/latest"

    def self.convert(from:, to:, amount:)
      from = from.to_s.upcase
      to = to.to_s.upcase
      amount = BigDecimal(amount.to_s)

      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(
        amount: amount.to_s("F"),
        from: from,
        to: to
      )

      res = Net::HTTP.get_response(uri)
      raise "FX API エラー: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      converted = data.dig("rates", to)
      raise "通貨コードが対応していない可能性があります: #{from} -> #{to}" if converted.nil?

      [BigDecimal(converted.to_s), data["date"]]
    end
  end
end
