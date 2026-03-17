# frozen_string_literal: true

module Popularity
  class MofaResidentImporter

    NAME_ALIASES = {
      "韓国" => ["大韓民国", "Republic of Korea", "Korea, Rep.", "KOR"],
      "大韓民国" => ["韓国", "Republic of Korea", "Korea, Rep.", "KOR"],

      "米国" => ["アメリカ", "アメリカ合衆国", "United States", "United States of America", "USA", "US"],
      "アメリカ" => ["米国", "アメリカ合衆国", "United States", "United States of America", "USA", "US"],
      "アメリカ合衆国" => ["米国", "アメリカ", "United States", "United States of America", "USA", "US"],

      "英国" => ["イギリス", "United Kingdom", "UK", "GBR"],
      "イギリス" => ["英国", "United Kingdom", "UK", "GBR"],

      "ロシア" => ["ロシア連邦", "Russia", "Russian Federation", "RUS"],
      "ロシア連邦" => ["ロシア", "Russia", "Russian Federation", "RUS"],

      "ベトナム" => ["ベトナム社会主義共和国", "Viet Nam", "Vietnam", "VNM"],
      "タイ" => ["タイ王国", "Thailand", "THA"],
      "シンガポール" => ["シンガポール共和国", "Singapore", "SGP"],
      "チェコ" => ["チェコ共和国", "Czech Republic", "CZE"],
      "南アフリカ" => ["南アフリカ共和国", "South Africa", "ZAF"],
      "エジプト" => ["エジプト・アラブ共和国", "Egypt", "EGY"],
      "パキスタン" => ["パキスタン・イスラム共和国", "Pakistan", "PAK"]
    }.freeze


    def self.refresh_all
      new.refresh!
    end

    def refresh!
      data = Popularity::MofaResidentFetcher.fetch
      rows = data[:rows] || []

      y = safe_year(data[:year])
      m = data[:month].to_i
      d = data[:day].to_i
      m = nil if m <= 0
      d = nil if d <= 0

      name_index = build_name_index

      matched = 0
      updated = 0
      unmatched = []

      rows.each do |r|
        n = r[:name].to_s
        cnt = r[:count].to_i
        next if n.strip.empty?
        next if cnt <= 0

        targets = find_targets(name_index, n)

        if targets.empty?
          unmatched << n
          Rails.logger.warn "[RESIDENT UNMATCHED] #{n}"
          next
        end

        matched += 1
        targets.each do |c|
          c.jp_resident_count = cnt

          if y
            c.jp_resident_year = y
            c.jp_resident_month = m
            c.jp_resident_day = d
            c.jp_resident_source_url = data[:source_url]
          end

          c.save!(validate: false)
          updated += 1
        end
      end

      {
        source_url: data[:source_url],
        total_rows: rows.size,
        matched: matched,
        updated: updated,
        unmatched_names: unmatched.uniq.sort
      }
    end

    private

    def safe_year(v)
      y = v.to_i
      return nil if y <= 0
      return nil if y < 2000
      return nil if y > (Time.current.year + 1)
      y
    end

    def build_name_index
      h = Hash.new { |hh, k| hh[k] = [] }

      Country.find_each do |c|
        add_index(h, c.name_ja, c)
        add_index(h, c.name_en, c) if c.name_en.present?
        add_index(h, c.iso3, c) if c.iso3.present?
      end

      h
    end

    def find_targets(index, name)
      key = norm(name)
      return [] if key.blank?

      return index[key].uniq if index.key?(key) && index[key].any?

      alias_names_for(name).each do |alt|
        alt_key = norm(alt)
        next if alt_key.blank?
        return index[alt_key].uniq if index.key?(alt_key) && index[alt_key].any?
      end

      hits = []
      index.each do |k, arr|
        next if k.empty?
        if k.include?(key) || key.include?(k)
          hits.concat(arr)
        end
      end
      hits.uniq
    end

    def norm(s)
      t = s.to_s.strip
      t = t.gsub(/\s+/, "")
      t = t.tr("／", "/")
      t = t.gsub(/（[^）]{0,}）/, "")
      t = t.gsub(/\([^)]{0,}\)/, "")
      t
    end
  end
end

def add_index(index, raw_name, country)
  key = norm(raw_name)
  return if key.blank?

  index[key] << country

  alias_names_for(raw_name).each do |alt|
    alt_key = norm(alt)
    next if alt_key.blank?
    index[alt_key] << country
  end
end

def alias_names_for(name)
  raw = name.to_s.strip
  normalized = norm(raw)

  hits = []

  self.class::NAME_ALIASES.each do |base, alts|
    all = [base, *alts]
    normalized_all = all.map { |v| norm(v) }
    if normalized_all.include?(normalized)
      hits.concat(all)
    end
  end

  hits.uniq
end
