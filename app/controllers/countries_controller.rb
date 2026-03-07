# frozen_string_literal: true

class CountriesController < ApplicationController
  def show
    @country = Country.only_countries.find(params[:id])

    areas = Country.where(iso3: [nil, ""]).to_a
    @subareas = subareas_for(@country, areas)
      .sort_by { |a| -(a.safety_level.to_i) }
  end

  private

  def subareas_for(country, areas)
    base_ja = country.name_ja.to_s.strip
    base_en = country.name_en.to_s.strip

    areas.select do |a|

      nja = a.name_ja.to_s.strip
      nen = a.name_en.to_s.strip

      hit_ja = !base_ja.empty? && !nja.empty? && nja.start_with?(base_ja)
      hit_en = !base_en.empty? && !nen.empty? && nen.downcase.start_with?(base_en.downcase)

      hit_ja || hit_en
    end
  end
end