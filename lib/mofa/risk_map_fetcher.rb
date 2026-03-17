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

      # 治安（渡航危険情報）だけで判定する
      max = r[:risk_level].to_i

      # 0/1 を含む場合だけ保存したい下限（riskのみ）
      # - 危険情報が存在しない（情報なし＝レベル0相当）なら 0
      # - レベル1が含まれるなら 1
      # - それ以外（2〜4のみ等）は保存しない（nil）
      min_for_store =
        if !r[:hazard_present]
          0
        else
          r[:risk_min_level]
        end

      country.update!(
        safety_risk_level: r[:risk_level],
        safety_infection_level: r[:infection_level], # 保存はするが、min/max判定には使わない
        safety_max_level: max,
        safety_min_level: min_for_store,
        safety_level: max,
        safety_source_updated_at: r[:source_updated_at],
        safety_fetched_at: fetched_at
      )
    end

    private

    def default_http
      Faraday.new do |f|
        f.options.timeout = 15
        f.options.open_timeout = 10
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

      url = "#{BASE}/#{code}.xml" # L.xml ではない
      res = @http.get(url)
      raise "MOFA fetch failed status=#{res.status} url=#{url}" unless res.status == 200

      body = res.body.to_s
      # HTMLが返ってきたら即エラーにして気づけるように
      if body.lstrip.start_with?("<!doctype", "<html")
        raise "MOFA returned HTML (not XML) url=#{url}"
      end

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
        risk_min_level: min_flag_level(hazard, "riskLevel"),
        infection_min_level: min_flag_level(infect, "infectionLevel"),
        hazard_present: hazard.any?,
        infect_present: infect.any?,
        has_level1_risk: any_flag_level?(hazard, "riskLevel", 1),
        has_level1_infection: any_flag_level?(infect, "infectionLevel", 1),
        source_updated_at: max_leave_date(mails)
      }
    end

    def info_long(mail)
      mail.at_xpath("infoNameLong")&.text.to_s
    end

    def min_flag_level(mails, prefix)
      return nil if mails.empty?
      1.upto(4) do |lv|
        return lv if mails.any? { |m| m.at_xpath("#{prefix}#{lv}")&.text.to_s.strip.upcase == "Y" }
      end
      nil
    end

    def max_flag_level(mails, prefix)
      return 0 if mails.empty?
      4.downto(1) do |lv|
        return lv if mails.any? { |m| m.at_xpath("#{prefix}#{lv}")&.text.to_s.strip.upcase == "Y" }
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
      mails.any? { |m| m.at_xpath("#{prefix}#{lv}")&.text.to_s.strip.upcase == "Y" }
    end
  end
end