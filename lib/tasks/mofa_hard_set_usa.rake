# frozen_string_literal: true

namespace :mofa do
  desc "Hard set MOFA code for USA only (JPN is ignored)"
  task hard_set_usa_code: :environment do
    usa_code = "0047" # アメリカ合衆国／米国（本土）

    updated = 0
    Country.where(iso3: "USA").find_each do |c|
      next if c.mofa_country_code == usa_code
      c.update!(mofa_country_code: usa_code)
      updated += 1
    end

    puts "done. updated=#{updated} USA=#{usa_code}"
  end
end