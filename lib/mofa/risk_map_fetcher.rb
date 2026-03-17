# frozen_string_literal: true

require "faraday"
require "nokogiri"

module Mofa
  class RiskMapFetcher
    BASE = "https://www.ezairyu.mofa.go.jp/opendata/country"

    def initialize(http: default_http)
      @http = http
    end

    def apply_to_country!(country)
      fetched_at = Time.current

      xml = fetch_xml!(country.mofa_country_code)
      r = parse(xml)

      max = r[:risk_level].to_i

      min_for_store =
        if !r[:hazard_present]
          0
        else
          r[:risk_min_level]
        end

      country.update!(
        safety_risk_level: r[:risk_level],
        safety_infection_level: r[:infection_level],
        safety_max_level: max,
        safety_min_level: min_for_store,
        safety_level: max,
        safety_source_updated_at: r[:source_updated_at],
        safety_fetched_at: fetched_at,
        last_error: nil
      )
    end

    private

    def default_http
      Faraday.new do |f|
        f.options.timeout = 5
        f.options.open_timeout = 3
        f.headers["User-Agent"] = "world-otokudo-ranking/1.0"
        f.headers["Accept"] = "application/xml,text/xml;q=0.9,*/*;q=0.8"
      end
    end

    def normalize_code(mofa_code)
      code = mofa_code.to_s.strip
      raise "mofa_country_code blank" if code.empty?
      code.rjust(4, "0")
    end

    def fetch_xml!(mofa_code)
      code = normalize_code(mofa_code)

      url = "#{BASE}/#{code}A.xml"
      Rails.logger.warn "[MOFA FETCH START] code=#{code} url=#{url}"

      res = @http.get(url)

      Rails.logger.warn "[MOFA FETCH END] code=#{code} status=#{res.status}"

      raise "MOFA fetch failed status=#{res.status} url=#{url}" unless res.status == 200

      body = res.body.to_s
      head = body.lstrip.downcase

      raise "MOFA returned blank body url=#{url}" if body.strip.empty?
      raise "MOFA returned HTML (not XML) url=#{url}" if head.start_with?("<!doctype", "<html")

      body
    end

    def parse(xml)
      doc = Nokogiri::XML(xml)
      mails = doc.xpath("//mail")

      hazard = mails.select { |m| m.at_xpath("infoType")&.text.to_s.strip == "T40" }
      infect = mails.select { |m| m.at_xpath("infoType")&.text.to_s.strip == "T41" }

      {
        risk_level: max_flag_level(hazard, "riskLevel"),
        infection_level: max_flag_level(infect, "infectionLevel"),
        risk_min_level: min_risk_level(hazard, "riskLevel"),
        infection_min_level: min_risk_level(infect, "infectionLevel"),
        hazard_present: hazard.any?,
        infect_present: infect.any?,
        source_updated_at: max_leave_date(mails)
      }
    end

    def flag_on?(value)
      %w[1 Y TRUE].include?(value.to_s.strip.upcase)
    end 

    def safe_area_present?(mail, prefix)
      urls = mail.xpath("mapImageUrl").map { |n| n.text.to_s.strip }

      # 公式例どおり、RiskMap_0 があれば 0 地域ありとみなす
      return true if prefix == "riskLevel" && urls.any? { |u| u.include?("RiskMap_0") }

      return true if prefix == "infectionLevel" && urls.any? { |u| u.include?("RiskMap_0") }

      false
    end
    
    def min_risk_level(mails, prefix)
      return nil if mails.empty?

      return 0 if mails.any? { |m| safe_area_present?(m, prefix) }

      1.upto(4) do |lv|
        return lv if mails.any? { |m| flag_on?(m.at_xpath("#{prefix}#{lv}")&.text) }
      end

      nil
    end

    def max_flag_level(mails, prefix)
      return 0 if mails.empty?

      4.downto(1) do |lv|
        return lv if mails.any? { |m| flag_on?(m.at_xpath("#{prefix}#{lv}")&.text) }
      end

      0
    end

    def max_leave_date(mails)
      times = mails.map do |m|
        s = m.at_xpath("leaveDate")&.text.to_s.strip
        next if s.empty?
        Time.zone.parse(s.tr("/", "-")) rescue nil
      end.compact

      times.max
    end

    def any_flag_level?(mails, prefix, lv)
      return false if mails.empty?

      mails.any? { |m| flag_on?(m.at_xpath("#{prefix}#{lv}")&.text) }
    end
  end
end