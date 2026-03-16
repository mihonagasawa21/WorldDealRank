# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

module CostIndex
  class RefreshFast
    CACHE_KEY_RAN_AT = "cost_index_refresh_fast_ran_at"
    CACHE_KEY_LOCK   = "cost_index_refresh_fast_lock"

    def self.call
      new.call
    end

    def call
      min_interval = ENV.fetch("REFRESH_FAST_MIN_INTERVAL_SECONDS", "600").to_i
      now = Time.current

      # 直前に実行済みならスキップ（0にすれば毎回実行）
      last = Rails.cache.read(CACHE_KEY_RAN_AT)
      if min_interval > 0 && last.present? && last > min_interval.seconds.ago
        return :skipped
      end

      # 多重起動防止（弱めのロック。十分ならOK）
      return :locked if Rails.cache.read(CACHE_KEY_LOCK).present?
      Rails.cache.write(CACHE_KEY_LOCK, true, expires_in: 20.minutes)

      begin
        # 国マスタ・ISO
        Mofa::CountryMasterFetcher.new.upsert_countries
        Countries::IsoMapper.new.fill_all

        # 安全情報（MOFA）
        Mofa::CountrySafetyFetcher.new.refresh_all

        # 人気（JTB）: 最新の月次データを入れたいなら必須
        Popularity::JtbOutboundFetcher.refresh_all

        # 為替（Frankfurter + 足りない分をWorldBank）
        Fx::FrankfurterFetcher.new.refresh_all
        WorldBank::FxFetcher.new.fill_missing_fx_all

        # PPP/PLR は年次で重いので「毎回」はしない（必要なら別途）
        # WorldBank::PppFetcher.new.refresh_all
        # WorldBank::PlrFetcher.new.refresh_all

        recalc_indexes(now)

        Rails.cache.write(CACHE_KEY_RAN_AT, now, expires_in: 2.days)
        :ok
      ensure
        Rails.cache.delete(CACHE_KEY_LOCK)
      end
    end

    private

    def recalc_indexes(now)
      japan = Country.japan
      if japan.nil?
        Country.update_all(last_error: "指数計算失敗: 日本が見つかりません")
        return
      end

      ensure_plr!(japan)
      jp_plr = japan.plr.to_d
      if jp_plr <= 0
        Country.update_all(last_error: "指数計算失敗: 日本PLR未計算")
        return
      end

      Country.find_each do |country|
        ensure_plr!(country)

        plr = country.plr.to_d
        plr = BigDecimal("1") if plr <= 0
        
        ratio_plr = Support::MathOps.div(plr, jp_plr)
        final = Support::MathOps.mul(BigDecimal("100"), ratio_plr)

        reason = nil
        reason = join_reason(reason, "FXなし(推計:PLR=1扱い含む可能性)") if country.fx_rate_usd.blank?
        reason = join_reason(reason, "PPP/PLRなし(推計:PLR=1)") if country.ppp_lcu_per_intl.blank? && country.plr.blank?

        country.update(
          final_index: final,
          deviation_pct: final - BigDecimal("100"),
          calculated_at: now,
          last_error: reason
        )
      rescue StandardError => e
        country.update(last_error: "指数計算失敗: #{e.class} #{e.message}")
      end
    end

    def ensure_plr!(country)
      return if country.plr.present? && country.plr.to_d > 0

      ppp = country.ppp_lcu_per_intl
      fx = country.fx_rate_usd

      if ppp.present? && fx.present? && fx.to_d != 0
        country.update(plr: ppp.to_d / fx.to_d)
        return
      end

      # 画面を成立させるための推計（厳密にしたいならここは nil のままにして除外設計にする）
      country.update(plr: BigDecimal("1")) if country.plr.blank?
    end

    def join_reason(base, add)
      b = base.to_s.strip
      return add if b.empty?
      "#{b} / #{add}"
    end
  end
end
