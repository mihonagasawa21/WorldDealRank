# lib/tasks/mofa.rake
namespace :mofa do
  desc "Update safety_level from MOFA Risk Map open data"
  task riskmap: :environment do
    STDOUT.sync = true
    puts "MOFA start env=#{Rails.env} db=#{ActiveRecord::Base.connection_db_config.database}"
    puts "Country.count=#{Country.count}"

    fetcher = Mofa::RiskMapFetcher.new
    ok = 0
    ng = 0

    Country.find_each do |country|
      next if country.mofa_country_code.blank?

      fetcher.apply_to_country!(country)
      ok += 1

      puts "ok #{country.name_ja} code=#{country.mofa_country_code} max=#{country.safety_max_level}" if ok <= 3
    rescue => e
      ng += 1
      puts "NG #{country.name_ja} code=#{country.mofa_country_code} #{e.class}: #{e.message}"
    end

    puts "MOFA done ok=#{ok} ng=#{ng}"
  end
end