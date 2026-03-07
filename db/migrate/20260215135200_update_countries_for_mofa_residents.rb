# frozen_string_literal: true

class UpdateCountriesForMofaResidents < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :jp_resident_count, :integer unless column_exists?(:countries, :jp_resident_count)
    add_column :countries, :jp_resident_year, :integer unless column_exists?(:countries, :jp_resident_year)
    add_column :countries, :jp_resident_month, :integer unless column_exists?(:countries, :jp_resident_month)
    add_column :countries, :jp_resident_day, :integer unless column_exists?(:countries, :jp_resident_day)
    add_column :countries, :jp_resident_source_url, :string unless column_exists?(:countries, :jp_resident_source_url)

    add_index :countries, :jp_resident_count unless index_exists?(:countries, :jp_resident_count)
  end
end
