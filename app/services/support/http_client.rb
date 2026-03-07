# frozen_string_literal: true

require "faraday"

module Support
  class HttpClient
    MAX_REDIRECT = 5

    def get_bytes(url)
      u = url.to_s
      MAX_REDIRECT.times do
        resp = Faraday.get(u) do |req|
          req.headers["User-Agent"] = "rate_match/1.0"
          req.headers["Accept"] = "*/*"
        end

        if [301, 302, 303, 307, 308].include?(resp.status)
          loc = resp.headers["location"]
          raise "redirect location missing" if loc.to_s.strip.empty?
          u = loc
          next
        end

        raise "HTTP #{resp.status}" unless resp.status.between?(200, 299)
        return resp.body
      end

      raise "too many redirects"
    end
  end
end
