# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

class Admin::CostIndexController < ApplicationController
  def index
    @popularity_result = nil
    load_cost_index_debug_data
  end

  def refresh
    recalc_indexes_only!

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "指数を再計算しました"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  def refresh_mofa
    Mofa::CountryMasterFetcher.new.upsert_countries
    Countries::IsoMapper.new.fill_all

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "MOFA国データを更新しました"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  def refresh_fx
    Fx::FrankfurterFetcher.new.refresh_all
    WorldBank::FxFetcher.new.fill_missing_fx_all

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "FXデータを更新しました"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  def refresh_ppp
    WorldBank::PppFetcher.new.refresh_all
    WorldBank::PlrFetcher.new.refresh_all

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "PPP・PLRデータを更新しました"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  def refresh_popularity
    @popularity_result = run_popularity_refresh!

    load_cost_index_debug_data

    if @popularity_result.is_a?(Hash)
      unmatched_count = Array(@popularity_result[:unmatched_names]).size
      flash.now[:notice] = "人気データを更新しました matched=#{@popularity_result[:matched]} updated=#{@popularity_result[:updated]} unmatched=#{unmatched_count}"
    else
      flash.now[:notice] = "人気データを更新しました"
    end

    render :index
  rescue => e
    handle_admin_error(e)
  end

  def recalc
    recalc_indexes_only!

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "指数を再計算しました"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  def refresh_photos
    updated = CostIndex::CountryPhotoRefreshService.call
    redirect_to admin_cost_index_path, notice: "写真更新が完了しました（#{updated}件）"
  rescue => e
    redirect_to admin_cost_index_path, alert: "写真更新でエラー: #{e.message}"
  end

  def refresh_risk
    Rails.logger.warn "=== REFRESH_RISK START ==="

    fetcher = Mofa::RiskMapFetcher.new
    min_present = 0
    partial_present = 0
    no_risk_count = 0
    error_count = 0

    Country.find_each do |country|
      next if country.mofa_country_code.blank?

      begin
        fetcher.apply_to_country!(country)
        country.reload

        max = country.safety_max_level.to_i
        min = country.safety_min_level

        if min.present?
          min_present += 1
        elsif max > 0
          partial_present += 1
          Rails.logger.warn "[ADMIN RISK PARTIAL] #{country.id} #{country.name_ja} code=#{country.mofa_country_code} max=#{max}"
        else
          no_risk_count += 1
        end
      rescue => e
        error_count += 1
        Rails.logger.error "[ADMIN RISK] #{country.id} #{country.name_ja} #{e.class}: #{e.message}"
      end
    end

    Rails.logger.warn "=== REFRESH_RISK END min_present=#{min_present} partial_present=#{partial_present} no_risk_count=#{no_risk_count} error_count=#{error_count} ==="

    @popularity_result = nil
    load_cost_index_debug_data
    flash.now[:notice] = "危険情報更新完了 minあり=#{min_present} 部分危険=#{partial_present} 危険情報なし=#{no_risk_count} エラー=#{error_count}"
    render :index
  rescue => e
    handle_admin_error(e)
  end

  private

  def handle_admin_error(error)
    @popularity_result ||= nil

    Rails.logger.error "[ADMIN COST] #{error.class}: #{error.message}"
    Rails.logger.error error.backtrace.first(20).join("\n") if error.backtrace.present?

    begin
      load_cost_index_debug_data
    rescue => load_error
      Rails.logger.error "[ADMIN COST LOAD] #{load_error.class}: #{load_error.message}"
      @problem_countries = []
      @sample_world_rows = []
      @score_map = {}
    end

    flash.now[:alert] = "エラー: #{error.class} #{error.message}"
    render :index, status: :unprocessable_entity
  end

  def run_popularity_refresh!
    return true unless Object.const_defined?(:Popularity)

    if Popularity.const_defined?(:MofaResidentImporter) && Popularity::MofaResidentImporter.respond_to?(:refresh_all)
      return Popularity::MofaResidentImporter.refresh_all
    end

    if Popularity.const_defined?(:MofaResidentImporter)
      importer = Popularity::MofaResidentImporter.new
      if importer.respond_to?(:refresh!)
        return importer.refresh!
      end
    end

    if Popularity.const_defined?(:MofaResidentFetcher) && Popularity::MofaResidentFetcher.respond_to?(:refresh_all)
      return Popularity::MofaResidentFetcher.refresh_all
    end

    true
  end

  def recalc_indexes_only!
    now = Time.current

    countries = Country.all.to_a
    raise "国データがありません" if countries.empty?

    japan = find_japan
    raise "日本が見つかりません" if japan.nil?

    ensure_plr!(japan)
    japan.reload

    raise "日本のPLRがありません" if japan.plr.blank? || japan.plr.to_d <= 0

    jp_plr = japan.plr.to_d

    Country.find_each do |country|
      begin
        ensure_plr!(country)
        country.reload

        plr = country.plr.to_d
        plr = BigDecimal("1") if plr <= 0

        ratio_plr = plr / jp_plr
        final = BigDecimal("100") * ratio_plr

        reason = nil
        reason = join_reason(reason, "FXなし") if country.fx_rate_usd.blank?
        reason = join_reason(reason, "PPPなし") if country.ppp_lcu_per_intl.blank?

        country.update_columns(
          final_index: final,
          deviation_pct: final - BigDecimal("100"),
          calculated_at: now,
          last_error: reason
        )
      rescue => e
        begin
          country.update_columns(last_error: "再計算失敗: #{e.class} #{e.message}")
        rescue StandardError
        end
      end
    end
  end

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
    @safety_min_count = countries.where.not(safety_min_level: nil).count
    @safety_max_count = countries.where.not(safety_max_level: nil).count

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