# frozen_string_literal: true

class Country < ApplicationRecord

  belongs_to :parent_country, class_name: "Country", optional: true

  scope :only_countries, -> { where(area_type: :country) }

  scope :not_japan, -> {
    where.not(iso3: "JPN")
      .where.not(iso2: "JP")
      .where.not(name_ja: "日本")
  }

  def self.ranking_candidates(safety:, show_areas:)
    rel = not_japan.where.not(final_index: nil)

    # show_areas=false のときは「国だけ」= iso3 を持つものだけ
    unless show_areas
      rel = rel.where.not(iso3: [nil, ""])
    end

    rel

    if safety.present?
      limit = safety.to_i
      rel = rel.where("safety_max_level <= ? OR safety_max_level IS NULL", limit)
    end
  end

  def iso_label
    iso3.presence || iso2.presence || "-"
  end

  def self.japan
    where("iso3 = ? OR iso2 = ? OR name_ja = ?", "JPN", "JP", "日本").first
  end

  def safety_label
    v = safety_max_level
    return "0" if v.nil? || v.to_i == 0
    "レベル#{v}"
  end

  def final_index_ui
    return "-" if final_index.nil?
    format("%.1f", final_index.to_f)
  end

  def base_name_for_parent
    s = name_ja.to_s
    if s.include?("（")
      s.split("（", 2).first.to_s.strip
    elsif s.include?("(")
      s.split("(", 2).first.to_s.strip
    else
      s.strip
    end
  end

  def base_en_for_parent
    s = name_en.to_s
    if s.include?("(")
      s.split("(", 2).first.to_s.strip
    else
      s.strip
    end
  end

  # 表示は「1通貨 = 何円」: JPY(1USD) / CUR(1USD)
  def fx_jpy_value(japan = nil)
    japan ||= Country.japan
    return nil if japan.nil? || japan.fx_rate_usd.nil?

    jpy_per_usd = japan.fx_rate_usd.to_d

    if currency_code.to_s.upcase == "USD"
      return jpy_per_usd
    end

    return nil if fx_rate_usd.nil?

    cur_per_usd = fx_rate_usd.to_d
    return nil if cur_per_usd == 0

    jpy_per_usd / cur_per_usd
  end

  def fx_jpy_text(japan = nil)
    v = fx_jpy_value(japan)
    return "-" if v.nil?

    f = v.to_f
    if f >= 100
      format("%.2f", f)
    elsif f >= 1
      format("%.3f", f)
    elsif f >= 0.1
      format("%.4f", f)
    else
      format("%.6f", f)
    end
  end

  def jp_resident_ui
    return "測定不能" if jp_resident_count.nil?
    ActiveSupport::NumberHelper.number_to_delimited(jp_resident_count.to_i)
  end

  def jp_resident_meta_text
    return "-" if jp_resident_year.blank?

    y = jp_resident_year.to_i
    m = jp_resident_month.present? ? jp_resident_month.to_i : nil
    d = jp_resident_day.present? ? jp_resident_day.to_i : nil

    if m && d
      "(#{y}年#{m}月#{d}日)"
    elsif m
      "(#{y}年#{m}月)"
    else
      "(#{y}年)"
    end
  end

  def self.popularity_latest_meta_text
    row = where.not(jp_resident_year: nil)
             .order(jp_resident_year: :desc, jp_resident_month: :desc, jp_resident_day: :desc)
             .first
    return nil unless row

    y = row.jp_resident_year
    m = row.jp_resident_month
    d = row.jp_resident_day

    if y && m && d
      "外務省 海外在留邦人数調査統計（#{y}年#{m}月#{d}日現在）"
    elsif y && m
      "外務省 海外在留邦人数調査統計（#{y}年#{m}月）"
    elsif y
      "外務省 海外在留邦人数調査統計（#{y}年）"
    else
      "外務省 海外在留邦人数調査統計"
    end
  end
end