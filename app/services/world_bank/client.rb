# frozen_string_literal: true

require "faraday"

module WorldBank
  class Client
    def self.connection
      Faraday.new(url: "https://api.worldbank.org") do |f|
        f.options.open_timeout = 10
        f.options.timeout = 90
        f.headers["User-Agent"] = "rate_match"
        f.adapter Faraday.default_adapter
      end
    end
  end
end
