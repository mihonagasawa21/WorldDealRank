# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

module CostIndex
  class RefreshAll
    def self.call
      new.call
    end

    def call
      now = Time.current

      Mofa::CountryMasterFetcher.new.upsert_countries
      Countries::IsoMapper.new.fill_all

      #Mofa::SafetyRefreshService.new.refresh_all_areas!

      refresh_popularity_safely

      Fx::FrankfurterFetcher.new.refresh_all
      WorldBank::FxFetcher.new.fill_missing_fx_all

      WorldBank::PppFetcher.new.refresh_all
      WorldBank::PlrFetcher.new.refresh_all

      recalc_indexes(now)
    end

    private

    def refresh_popularity_safely
      return true unless Object.const_defined?(:Popularity)

      if Popularity.const_defined?(:MofaResidentImporter) && Popularity::MofaResidentImporter.respond_to?(:refresh_all)
        Popularity::MofaResidentImporter.refresh_all
        return true
      end

      if Popularity.const_defined?(:MofaResidentImporter)
        importer = Popularity::MofaResidentImporter.new
        if importer.respond_to?(:refresh!)
          importer.refresh!
          return true
        end
      end

      if Popularity.const_defined?(:MofaResidentFetcher) && Popularity::MofaResidentFetcher.respond_to?(:refresh_all)
        Popularity::MofaResidentFetcher.refresh_all
        return true
      end

      true
    rescue StandardError => e
      puts "Popularity refresh skipped: #{e.class} #{e.message}"
      true
    end

    def recalc_indexes(now)
      japan = find_japan
      if japan.nil?
        Country.update_all(last_error: "指数計算失敗: 日本が見つかりません")
        return
      end

      ensure_plr!(japan)
      japan.reload

      jp_plr = japan.plr.to_d
      if jp_plr <= 0
        Country.update_all(last_error: "指数計算失敗: 日本PLR未計算")
        return
      end

      jp_tour = tourism_coef(japan)
      jp_tour = BigDecimal("1") if jp_tour <= 0

      Country.only_countries.find_each do |country|
        ensure_plr!(country)
        country.reload

        plr = country.plr.to_d
        plr = BigDecimal("1") if plr <= 0

        tour = tourism_coef(country)
        tour = BigDecimal("1") if tour <= 0

        ratio_plr = Support::MathOps.div(plr, jp_plr)
        ratio_tour = Support::MathOps.div(tour, jp_tour)

        base100 = Support::MathOps.mul(BigDecimal("100"), ratio_plr)
        final = Support::MathOps.mul(base100, ratio_tour)

        reason = nil
        if country.fx_rate_usd.blank?
          reason = join_reason(reason, "FXなし(推計:PLR=1扱い含む可能性)")
        end
        if country.ppp_lcu_per_intl.blank? && country.plr.blank?
          reason = join_reason(reason, "PPP/PLRなし(推計:PLR=1)")
        end

        country.update_columns(
          final_index: final,
          deviation_pct: final - BigDecimal("100"),
          calculated_at: now,
          last_error: reason
        )
      rescue StandardError => e
        begin
          country.update_columns(last_error: "指数計算失敗: #{e.class} #{e.message}")
        rescue StandardError
        end
      end
    end

    def find_japan
      Country.japan ||
        Country.where("upper(iso3) = ?", "JPN").first ||
        Country.where("upper(iso2) = ?", "JP").first ||
        Country.where("upper(currency_code) = ?", "JPY").first ||
        Country.where("name_ja LIKE ?", "%日本%").first ||
        Country.where("lower(name_en) = ?", "japan").first
    rescue StandardError
      nil
    end

    def ensure_plr!(country)
      return if country.plr.present? && country.plr.to_d > 0

      ppp = country.ppp_lcu_per_intl
      fx = country.fx_rate_usd

      if ppp.present? && fx.present? && fx.to_d != 0
        country.update_columns(plr: ppp.to_d / fx.to_d)
        return
      end

      country.update_columns(plr: BigDecimal("1")) if country.plr.blank?
    rescue StandardError
      begin
        country.update_columns(plr: BigDecimal("1")) if country.plr.blank?
      rescue StandardError
      end
    end

    def tourism_coef(country)
      if country.respond_to?(:tourism_coef_or_default)
        country.tourism_coef_or_default.to_d
      elsif country.respond_to?(:tourism_coef) && country.tourism_coef.present?
        country.tourism_coef.to_d
      else
        BigDecimal("1")
      end
    end

    def join_reason(base, add)
      b = base.to_s.strip
      return add if b.empty?
      "#{b} / #{add}"
    end
  end
end
