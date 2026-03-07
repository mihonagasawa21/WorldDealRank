# frozen_string_literal: true

namespace :countries do
  desc "Refresh all country data"
  task refresh_all: :environment do
    CostIndex::RefreshAll.call
    puts "countries:refresh_all done"
  rescue StandardError => e
    puts "countries:refresh_all failed: #{e.class} #{e.message}"
    puts e.full_message(highlight: false)
    raise
  end
end
