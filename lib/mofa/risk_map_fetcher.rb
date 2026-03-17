\# frozen_string_literal: true

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

      max_for_store = r[:risk_max_level].to_i

      min_for_store =
        if !r[:hazard_present]
          0
        else
          r[:risk_min_level]
        end

      country.update!(
        safety_risk_level: max_for_store,
        safety_infection_level: r[:infection_max_level].to_i,
        safety_max_level: max_for_store,
        safety_min_level: min_for_store,
        safety_level: min_for_store,
        safety_updated_at: r[:source_updated_at],
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
      doc.remove_namespaces!

      mails = doc.xpath("//mail")

      hazard = mails.select { |m| text_at(m, "infoType") == "T40" }
      infect = mails.select { |m| text_at(m, "infoType") == "T41" }

      {
        risk_max_level: max_flag_level(hazard, "riskLevel"),
        infection_max_level: max_flag_level(infect, "infectionLevel"),
        risk_min_level: min_flag_level(hazard, :risk),
        infection_min_level: min_flag_level(infect, :infection),
        hazard_present: hazard.any?,
        infect_present: infect.any?,
        source_updated_at: max_leave_date(mails)
      }
    end

    def text_at(node, name)
      node.at_xpath("./#{name}")&.text.to_s.strip
    end

    def flag_on?(value)
      %w[1 Y TRUE].include?(value.to_s.strip.upcase)
    end

    def map_urls(mail)
      mail.xpath(".//*[local-name()='mapImageUrl']")
          .map { |n| n.text.to_s.strip }
          .reject(&:empty?)
    end

    def safe_area_present?(mail, kind)
      urls = map_urls(mail).map(&:downcase)
      return false if urls.empty?

      patterns =
        case kind
        when :risk
          %w[
            riskmap_0
            targetriskmap_0
            districtriskmap_0
          ]
        when :infection
          %w[
            infectionmap_0
            targetinfectionmap_0
            districtinfectionmap_0
            riskmap_0
          ]
        else
          []
        end

      urls.any? do |u|
        patterns.any? { |p| u.include?(p) }
      end
    end

    def min_flag_level(mails, kind)
      return nil if mails.empty?

      return 0 if mails.any? { |m| safe_area_present?(m, kind) }

      prefix = (kind == :risk ? "riskLevel" : "infectionLevel")

      1.upto(4) do |lv|
        return lv if mails.any? { |m| flag_on?(m.at_xpath("./*[local-name()='#{prefix}#{lv}']")&.text) }
      end

      nil
    end

    def max_flag_level(mails, prefix)
      return 0 if mails.empty?

      4.downto(1) do |lv|
        return lv if mails.any? { |m| flag_on?(m.at_xpath("./*[local-name()='#{prefix}#{lv}']")&.text) }
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
  end
end