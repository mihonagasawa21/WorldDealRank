# frozen_string_literal: true

namespace :popularity do
  desc "人気更新（外務省 在留邦人数）"
  task refresh: :environment do
    puts "popularity:refresh (MOFA residents)"
    res = Popularity::MofaResidentImporter.new.refresh!
    puts "source_url: #{res[:source_url]}"
    puts "total_rows: #{res[:total_rows]}"
    puts "matched: #{res[:matched]}"
    puts "updated: #{res[:updated]}"
    if res[:unmatched_names].any?
      puts "unmatched_names (#{res[:unmatched_names].size}):"
      res[:unmatched_names].each { |n| puts "  - #{n}" }
    end
  end

  desc "人気データのカバレッジ確認"
  task :coverage, [:level_mode, :include_subregions] => :environment do |_t, args|
    safety = (args[:level_mode].presence || "safe_lv2").to_s
    show_areas = %w[1 true yes on].include?(args[:include_subregions].to_s.strip.downcase)

    base = Country.ranking_candidates(safety: safety, show_areas: show_areas).to_a

    # show_areas=false のときは iso3 空を除外しているので、そのまま件数で見る
    candidates = base.size
    present = base.count { |c| !c.jp_resident_count.nil? }
    missing = candidates - present

    puts "popularity:coverage (safety=#{safety}, show_areas=#{show_areas}, japan excluded)"
    puts "candidates: #{candidates}"
    puts "popularity_present: #{present}"
    puts "popularity_missing: #{missing}"
  end
end
