# frozen_string_literal: true

namespace :cost_index do
  desc "Refresh all datasets (MOFA, popularity, FX, PPP) and recalc indexes"
  task refresh_all: :environment do
    CostIndex::RefreshAll.call
    puts "OK: refreshed at #{Time.current}"
  rescue StandardError => e
    warn "NG: #{e.class} #{e.message}"
    raise
  end
end
