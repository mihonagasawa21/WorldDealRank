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

      max_for_store = r[:risk_max_level].to_i

      special_min_zero_iso3 = %w[THA MYS]

      min_for_store =
        if !r[:hazard_present]
          0
        elsif special_min_zero_iso3.include?(country.iso3.to_s.upcase)
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
        risk_max_level: max_level_from_xml(hazard, :risk),
        infection_max_level: max_level_from_xml(infect, :infection),
        risk_min_level: min_level_from_xml(hazard, :risk),
        infection_min_level: min_level_from_xml(infect, :infection),
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

    def min_level_from_xml(mails, kind)
      return nil if mails.empty?

      levels = levels_from_urls(mails, kind)
      return levels.min if levels.any?

      levels = levels_from_flags(mails, kind)
      return levels.min if levels.any?

      nil
    end

    def max_level_from_xml(mails, kind)
      return 0 if mails.empty?

      url_levels = levels_from_urls(mails, kind)
      flag_levels = levels_from_flags(mails, kind)
      levels = (url_levels + flag_levels).uniq

      return levels.max if levels.any?

      0
    end

    def levels_from_flags(mails, kind)
      prefix = (kind == :risk ? "riskLevel" : "infectionLevel")

      levels = []

      1.upto(4) do |lv|
        levels << lv if mails.any? { |m| flag_on?(text_at(m, "#{prefix}#{lv}")) }
      end

      levels
    end

    def levels_from_urls(mails, kind)
      mails.flat_map { |m| levels_from_map_urls(m, kind) }.uniq.sort
    end

    def levels_from_map_urls(mail, kind)
      urls = map_urls(mail)
      return [] if urls.empty?

      urls.filter_map do |url|
        s = url.to_s.downcase

        relevant =
          case kind
          when :risk
            s.include?("riskmap")
          when :infection
            s.include?("infectionmap") || s.include?("riskmap")
          else
            false
          end

        next unless relevant

        m =
          s.match(/(?:target|district)?(?:risk|infection)map[_-]?([0-4])(?:\.html?)?(?:\?|$)/) ||
          s.match(/map[_-]?([0-4])(?:\.html?)?(?:\?|$)/) ||
          s.match(/[_\/-]([0-4])(?:\.html?)?(?:\?|$)/)

        m && m[1].to_i
      end
    end

    def max_leave_date(mails)
      times = mails.map do |m|
        s = m.at_xpath("leaveDate")&.text.to_s.strip
        next if s.empty?
        Time.zone.parse(s.tr("/", "-")) rescue nil
      end.compact

      times.max
    end