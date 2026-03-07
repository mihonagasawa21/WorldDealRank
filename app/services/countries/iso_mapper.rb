# frozen_string_literal: true

require "countries"

module Countries
  class IsoMapper
    def fill_all
      Country.find_each { |country| fill_one(country) }
    end

    def fill_one(country)
      return if country.iso3.present? && country.currency_code.present?

      iso = find_iso_by_names(country.name_ja, country.name_en)
      if iso.nil?
        country.update(last_error: "ISO推定失敗: 該当なし")
        return
      end

      country.iso2 = iso.alpha2
      country.iso3 = iso.alpha3
      country.name_en = best_en_name(iso, country.name_en)

      cc = extract_currency_code(iso)
      country.currency_code = cc if cc.present?

      country.last_error = nil if country.last_error.to_s.start_with?("ISO推定失敗")
      country.save!(validate: false)
    rescue StandardError => e
      country.update(last_error: "ISO推定失敗: #{e.class} #{e.message}")
    end

    private

    def find_iso_by_names(name_ja, name_en)
      ja = normalize(name_ja)
      en = normalize(name_en)

      candidates = ISO3166::Country.all

      hit = best_match(ja, candidates) if ja.present?
      return hit if hit

      hit = best_match(en, candidates) if en.present?
      return hit if hit

      # 「スラッシュ併記」対応
      if name_ja.to_s.include?("/") || name_ja.to_s.include?("／")
        parts = name_ja.to_s.split(/[\/／]/).map { |x| normalize(x) }.reject(&:empty?)
        parts.each do |p|
          hit = best_match(p, candidates)
          return hit if hit
        end
      end

      nil
    end

    def best_match(target, candidates)
      return nil if target.to_s.strip.empty?

      # 1) 完全一致
      candidates.each do |c|
        names = normalized_names(c)
        return c if names.include?(target)
      end

      # 2) 部分一致（短すぎる語は誤爆しやすいので長さ制限）
      if target.length >= 4
        candidates.each do |c|
          names = normalized_names(c)
          return c if names.any? { |n| n.include?(target) }
        end
        candidates.each do |c|
          names = normalized_names(c)
          return c if names.any? { |n| target.include?(n) && n.length >= 4 }
        end
      end

      nil
    end

    def normalized_names(iso)
      names = []

      if iso.respond_to?(:translations) && iso.translations.is_a?(Hash)
        names.concat(iso.translations.values)
      end

      names << iso.iso_short_name if iso.respond_to?(:iso_short_name)
      names << iso.common_name if iso.respond_to?(:common_name)

      if iso.respond_to?(:unofficial_names)
        names.concat(Array(iso.unofficial_names))
      end

      if iso.respond_to?(:names)
        names.concat(Array(iso.names))
      end

      names.compact.map { |x| normalize(x) }.reject(&:empty?).uniq
    end

    def best_en_name(iso, fallback)
      if iso.respond_to?(:iso_short_name) && iso.iso_short_name.present?
        iso.iso_short_name
      elsif iso.respond_to?(:common_name) && iso.common_name.present?
        iso.common_name
      else
        fallback.to_s
      end
    end

    def extract_currency_code(iso)
      # 最優先
      if iso.respond_to?(:currency_code) && iso.currency_code.present?
        return iso.currency_code.to_s.upcase
      end

      cur = iso.respond_to?(:currency) ? iso.currency : nil

      if cur.is_a?(Hash)
        code = cur["code"] || cur[:code]
        return code.to_s.upcase if code.present?
      end

      if cur.is_a?(Array)
        code = cur.first
        return code.to_s.upcase if code.present?
      end

      if cur.present?
        # 文字列として取れた場合の最後の保険
        s = cur.to_s.strip.upcase
        return s if s.match?(/\A[A-Z]{3}\z/)
      end

      ""
    end

    def normalize(s)
      t = s.to_s.strip
      return "" if t.empty?

      t = t.tr("　", " ")
      t = t.gsub(/\s+/, " ")
      t = t.gsub(/[（）\(\)\[\]【】]/, "")
      t = t.gsub(/[・,，]/, " ")
      t = t.gsub(/\s+/, " ")
      t.downcase.strip
    end
  end
end
