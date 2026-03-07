# frozen_string_literal: true

module Popularity
  class MofaResidentImporter
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
        h[norm(c.name_ja)] << c
        h[norm(c.name_en)] << c if c.name_en.present?
        h[norm(c.iso3)] << c if c.iso3.present?
      end
      h
    end

    def find_targets(index, name)
      key = norm(name)
      return index[key] if index.key?(key) && index[key].any?

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
