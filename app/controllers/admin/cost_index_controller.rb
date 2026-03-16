# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

class Admin::CostIndexController < ApplicationController
  def index
    load_cost_index_debug_data
  end

  def refresh
    now = Time.current

    countries = Country.all.to_a
    raise "国データがありません" if countries.empty?

    japan = find_japan
    raise "日本が見つかりません" if japan.nil?

    ensure_plr!(japan)
    japan.reload

    raise "日本のPLRがありません" if japan.plr.blank? || japan.plr.to_d <= 0

    jp_plr = japan.plr.to_d

    updated_count = 0
    error_count = 0

    Country.find_each do |country|
      begin
        ensure_plr!(country)
        country.reload

        plr = country.plr.to_d
        plr = BigDecimal("1") if plr <= 0

        final = BigDecimal("100") * (plr / jp_plr)

        reason = nil
        reason = join_reason(reason, "FXなし") if country.fx_rate_usd.blank?
        reason = join_reason(reason, "PPPなし") if country.ppp_lcu_per_intl.blank?
        reason = join_reason(reason, "PLR推計") if country.plr.blank? || country.plr.to_d <= 0

        country.update_columns(
          final_index: final,
          deviation_pct: final - BigDecimal("100"),
          calculated_at: now,
          last_error: reason
        )

        updated_count += 1
      rescue => e
        error_count += 1
        begin
          country.update_columns(last_error: "再計算失敗: #{e.class} #{e.message}")
        rescue StandardError
        end
      end
    end

    load_cost_index_debug_data
    flash.now[:notice] = "再計算完了: #{updated_count}件更新 / #{error_count}件エラー"
    render :index

  rescue => e
    begin
      load_cost_index_debug_data
    rescue => load_error
      Rails.logger.error "[ADMIN COST] load error #{load_error.class}: #{load_error.message}"
      @problem_countries = []
      @sample_world_rows = []
      @score_map = {}
    end

    flash.now[:alert] = "更新中にエラーが発生しました: #{e.class} #{e.message}"
    render :index, status: :unprocessable_entity
  end

  private

  def load_cost_index_debug_data
    @problem_countries = []
    @sample_world_rows = []
    @score_map = {}

    countries = Country.order(:name_ja)

    @total_count = countries.count
    @final_index_count = countries.where.not(final_index: nil).count
    @resident_count_count = countries.where.not(jp_resident_count: nil).count
    @calculated_at_count = countries.where.not(calculated_at: nil).count
    @last_error_count = countries.where.not(last_error: [nil, ""]).count
    @latest_calculated_at = countries.where.not(calculated_at: nil).maximum(:calculated_at)

    @fx_count = countries.where.not(fx_rate_usd: nil).count
    @ppp_count = countries.where.not(ppp_lcu_per_intl: nil).count
    @plr_count = countries.where.not(plr: nil).count

    @problem_countries = countries.select do |c|
      c.final_index.nil? || c.jp_resident_count.nil? || c.last_error.present?
    end

    @sample_world_rows = countries.limit(30).to_a

    begin
      @score_map = CostIndex::RankingScorer.new(countries).score_map || {}
    rescue => e
      Rails.logger.error "[ADMIN COST] score_map error #{e.class}: #{e.message}"
      @score_map = {}
    end
  end

  def find_japan
    Country.japan ||
      Country.where("upper(iso3) = ?", "JPN").first ||
      Country.where("upper(iso2) = ?", "JP").first ||
      Country.where("upper(currency_code) = ?", "JPY").first ||
      Country.where("name_ja LIKE ?", "%日本%").first ||
      Country.where("lower(name_en) = ?", "japan").first
  end

  def ensure_plr!(country)
    return if country.plr.present? && country.plr.to_d > 0

    ppp = country.ppp_lcu_per_intl
    fx = country.fx_rate_usd

    if ppp.present? && fx.present? && fx.to_d != 0
      country.update_columns(plr: ppp.to_d / fx.to_d)
      return
    end

    country.update_columns(plr: BigDecimal("1"))
  rescue => e
    begin
      country.update_columns(plr: BigDecimal("1"))
    rescue StandardError
    end
    Rails.logger.error "[ADMIN COST] ensure_plr error #{country.id}: #{e.class} #{e.message}"
  end

  def join_reason(base, add)
    b = base.to_s.strip
    return add if b.empty?
    "#{b} / #{add}"
  end
end