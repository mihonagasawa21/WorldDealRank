# frozen_string_literal: true

class Admin::CostIndexController < ApplicationController
  def index
    load_cost_index_debug_data
  end

  def refresh
    CostIndex::RefreshAll.call
    load_cost_index_debug_data

    flash.now[:notice] = "更新処理を実行しました"
    render :index
  rescue => e
    load_cost_index_debug_data rescue nil
    flash.now[:alert] = "更新中にエラーが発生しました: #{e.class} #{e.message}"
    render :index, status: :unprocessable_entity
  end

  private

  def load_cost_index_debug_data
    countries = Country.order(:name_ja)

    @countries = countries
    @total_count = countries.count
    @final_index_count = countries.where.not(final_index: nil).count
    @resident_count_count = countries.where.not(jp_resident_count: nil).count
    @calculated_at_count = countries.where.not(calculated_at: nil).count
    @last_error_count = countries.where.not(last_error: [nil, ""]).count
    @latest_calculated_at = countries.where.not(calculated_at: nil).maximum(:calculated_at)

    @problem_countries = countries.select do |c|
      c.final_index.nil? || c.jp_resident_count.nil? || c.last_error.present?
    end

    @sample_world_rows = countries.limit(30)
    @score_map = CostIndex::RankingScorer.new(countries).score_map
  end
end