# frozen_string_literal: true

class PagesController < ApplicationController
  helper_method :safety_text, :safety_style, :popular_text, :warn_text, :total_score_text, :rank_value

  CURRENCIES = %w[
    JPY USD EUR GBP AUD CAD CHF CNY KRW SGD HKD THB TWD INR IDR MYR PHP VND
    NZD SEK NOK DKK PLN CZK HUF TRY ZAR MXN BRL ILS ISK RON BGN
  ].freeze

  def ranking
    @top_n = 10
    @sort = "rank"
    @safety = "lv1"
    @q = ""

    base_rel = Country.not_japan.where.not(iso3: [nil, ""])
    base_rel = base_rel.where.not(iso3: BLACKLIST_ISO3) if defined?(BLACKLIST_ISO3)

    # WORLDと同じ：母集団（正規化の基準）は全体で固定
    base_list = base_rel.to_a

    # 表示用（検索なし）
    filtered_list = base_list
    @countries = filter_by_safety(filtered_list, @safety)

    # WORLDと同じ：スコアは全体で一回だけ計算して引く
    all_scores = CostIndex::RankingScorer.new(base_list).score_map
    @score_map = @countries.each_with_object({}) { |c, m| m[c.id] = all_scores[c.id] }

    # WORLDと同じ：rank並び（popular補正込み）
    @countries =
      @countries.sort_by do |c|
        s = @score_map[c.id]
        rec = s ? s[:recommend] : nil
        adj = adjust_recommend_for_low_popularity(rec, c.jp_resident_count)
        -(adj || -1)
      end

    # これが「WORLD上位10」
    @recommended = @countries.first(@top_n)

    # rankingページで必要なら（表示だけのため）
    @subareas_by_id = {}
    @warn_by_id = {}
    @display_level_by_id = {}
  end

  def world
    @sort   = params[:sort].presence   || "rank"
    @safety = params[:safety].presence || "lv1"
    @q      = params[:q].to_s.strip

    base_rel = Country.not_japan.where.not(iso3: [nil, ""])
    base_rel = base_rel.where.not(iso3: BLACKLIST_ISO3) if defined?(BLACKLIST_ISO3)

    # 母集団（正規化の基準）は全体で固定
    base_list = base_rel.to_a

    # 国だけの安全レベル表示（地域は見ない）
    @display_level_by_id = base_list.each_with_object({}) { |c, m| m[c.id] = c.safety_max_level }
    @warn_by_id = {}

    # スコアは母集団で一回だけ計算
    all_scores = CostIndex::RankingScorer.new(base_list).score_map

    # 表示対象だけ検索
    filtered_rel = apply_search(base_rel, @q)
    filtered_list = filtered_rel.to_a
    @countries = filter_by_safety(filtered_list, @safety)

    # 表示スコアは「全体スコア」から引く
    @score_map = @countries.each_with_object({}) { |c, m| m[c.id] = all_scores[c.id] }

    if @sort == "rank"
      @countries = @countries.sort_by { |c| -(rank_value(c) || -1) }
    else
      @countries = sort_countries(@countries, @sort)
    end
  end

  # 国詳細（ページとしては作ってある前提）
  def country
    @country = Country.only_countries.find(params[:id])

    areas = Country.where(iso3: [nil, ""]).to_a
    @subareas = subareas_for(@country, areas).sort_by { |a| -(a.safety_level.to_i) }
  end

  def fx
    @currencies = ["JPY","USD","EUR","GBP","AUD","CAD","CHF","CNY","KRW","HKD","SGD","THB","TWD","INR","IDR","MYR","PHP","VND"]

    @from = params[:from].presence || "USD"
    @to   = params[:to].presence || "JPY"
    @amount_str = params[:amount].presence || "100"

    # 選択中の通貨を「候補の最後」に回す（見た目は同じ、並びだけ固定）
    from_list = @currencies - [@from]
    from_list << @from if @from.present?

    to_list = @currencies - [@to]
    to_list << @to if @to.present?

    @currency_options_from = from_list.map { |iso| [view_context.currency_ja(iso), iso] }
    @currency_options_to   = to_list.map   { |iso| [view_context.currency_ja(iso), iso] }

    @converted_amount = nil
    @rate_per_1 = nil
    @rate_date = nil
    @error = nil

    return unless params.key?(:amount) || params.key?(:from) || params.key?(:to)

    begin
      amount = BigDecimal(@amount_str.to_s)
      raise ArgumentError, "金額は 0 より大きい数にしてください" if amount <= 0

      converted, date = Fx::CurrencyConverter.convert(from: @from, to: @to, amount: amount)
      @converted_amount = converted
      @rate_per_1 = (converted / amount)
      @rate_date = date
    rescue => e
        Rails.logger.error("[FX] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(15).join("\n"))
      @error = e.message
    end
  end

  private

  def rank_value(country)
    s = @score_map[country.id]
    rec = s ? s[:recommend] : nil
    adjust_recommend_for_low_popularity(rec, country.jp_resident_count)
  end

  def apply_search(rel, q)
    return rel if q.empty?

    like = "%" + q + "%"
    qd = q.downcase
    rel.where(
      "name_ja LIKE ? OR iso3 LIKE ? OR iso2 LIKE ? OR lower(name_en) LIKE ?",
      like, like, like, "%" + qd + "%"
    )
  end

  def filter_by_safety(list, safety)
    list.select do |c|
      min = c.safety_min_level
      max = c.safety_max_level

      next false if min.nil? && max.nil?

      case safety.to_s
      when "none"
        min.to_i == 0
      when "lv1"
        min.to_i <= 1
      else
        true
      end
    end
  end

  def sort_countries(list, sort)
    case sort.to_s
    when "rank"
      list.sort_by do |c|
        s = @score_map[c.id] || {}
        rec = s[:recommend]
        adj = adjust_recommend_for_low_popularity(rec, c.jp_resident_count)
        -(adj || -1)
      end
    when "popular"
      big = 1_000_000_000_000
      list.sort_by { |c| c.jp_resident_count.nil? ? big : -(c.jp_resident_count.to_i) }
    when "cheap"
      big = 1_000_000_000_000
      list.sort_by { |c| c.final_index.nil? ? big : c.final_index.to_f }
    when "name"
      list.sort_by { |c| c.name_ja.to_s }
    else
      list.sort_by { |c| c.name_ja.to_s }
    end
  end

  def group_subareas(parents, areas)
    parents.map do |c|
      subs = subareas_for(c, areas)
      display_level = display_safety_level(c, subs)

      warn = {
        has_lv2_area: subs.any? { |a| a.safety_level.to_i == 2 },
        has_lv34_area: subs.any? { |a| a.safety_level.to_i >= 3 },
        country_level_is_lv34: c.safety_level.to_i >= 3
      }

      eligible = eligible_country?(c, subs)

      { country: c, subareas: subs, display_level: display_level, warn: warn, eligible: eligible }
    end
  end

  def eligible_country?(country, subareas)
    list = [country] + subareas

    has_safe = list.any? { |x| x.safety_level.nil? || x.safety_level.to_i <= 2 }
    return false unless has_safe

    all_bad = list.all? { |x| x.safety_level && x.safety_level.to_i >= 3 }
    !all_bad
  end

  def subareas_for(country, areas)
    base_ja = country.name_ja.to_s.strip
    base_en = country.name_en.to_s.strip

    areas.select do |a|

      nja = a.name_ja.to_s.strip
      nen = a.name_en.to_s.strip

      hit_ja = !base_ja.empty? && !nja.empty? && nja.start_with?(base_ja)
      hit_en = !base_en.empty? && !nen.empty? && nen.downcase.start_with?(base_en.downcase)

      hit_ja || hit_en
    end
  end

  def display_safety_level(country, subareas)
    list = [country] + subareas
    return nil if list.any? { |x| x.safety_level.nil? }

    safe = list.map { |x| x.safety_level.to_i }.select { |lv| lv <= 2 }
    return safe.min if safe.any?

    list.map { |x| x.safety_level.to_i }.min
  end

  def adjust_recommend_for_low_popularity(recommend, jp_resident_count)
    return nil if recommend.nil?

    rec = recommend.to_f

    cnt = jp_resident_count
    return (rec - 12.0) if cnt.nil?

    c = cnt.to_i
    return (rec - 20.0) if c > 0 && c < 200
    return (rec - 10.0) if c >= 200 && c < 1000
    rec
  end

  def total_score_text(score_hash)
    v = score_hash ? score_hash[:recommend] : nil
    return "-" if v.nil?
    format("%.1f", v.to_f)
  end

  def popular_text(country, popular_score)
    return "測定不能" if country.jp_resident_count.nil?
    return "-" if popular_score.nil?
    popular_score.to_i.to_s
  end

  def safety_text(country)
    min = country.safety_min_level
    max = country.safety_max_level.to_i

    return "要確認" if min.nil?
    return "危険情報なし" if min.to_i == 0

    min.to_i.to_s
  end

  def safety_style(country)
    min = country.safety_min_level
    max = country.safety_max_level.to_i

    base = "padding:2px 6px;display:inline-block;font-weight:800;border-radius:0;"
    return base + "background:#e9eefb;" if max <= 0
    return base + "background:#fff1c9;" if min.nil?

    case min.to_i
    when 0 then base + "background:#e9eefb;"
    when 1 then base + "background:#dff5e6;"
    when 2 then base + "background:#ffe08a;"
    else        base + "background:#ffd0d0;"
    end
  end

  def warn_text(country)
    max = country.safety_max_level.to_i
    min = country.safety_min_level

    return "" if min.nil?
    return "" if min.to_i >= 2
    return "" if max <= min.to_i

    "注：一部地域で最大危険レベル#{max}です"
  end

end