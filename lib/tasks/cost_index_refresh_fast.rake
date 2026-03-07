# frozen_string_literal: true

namespace :cost_index do
  desc "Refresh fast (MOFA, popularity, FX) and recalc indexes"
  task refresh_fast: :environment do
    CostIndex::RefreshFast.call
    puts "OK: refresh_fast ran at #{Time.current}"
  rescue StandardError => e
    warn "NG: #{e.class} #{e.message}"
    raise
  end
end
