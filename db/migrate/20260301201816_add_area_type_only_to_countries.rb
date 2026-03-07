class AddAreaTypeOnlyToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :area_type, :integer, null: false, default: 0 unless column_exists?(:countries, :area_type)
    add_index :countries, :area_type unless index_exists?(:countries, :area_type)
  end
end