# frozen_string_literal: true

module Mofa
  class SafetyRefreshService
    def initialize(fetcher: Mofa::RiskMapFetcher.new)
      @fetcher = fetcher
    end

    # 国だけ更新（ランキングの国一覧用）
    def refresh_countries!
      Country.only_countries.find_each { |c| @fetcher.apply_to_country!(c) }
    end

    # 国＋地域も更新（観光地表示も含めたい時）
    #def refresh_all_areas!
      #Country.find_each { |c| @fetcher.apply_to_country!(c) }
    #end
  end
end