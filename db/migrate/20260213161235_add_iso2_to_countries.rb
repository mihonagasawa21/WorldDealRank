class AddIso2ToCountries < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:countries, :iso2)
      add_column :countries, :iso2, :string
    end

    unless index_exists?(:countries, :iso2)
      add_index :countries, :iso2
    end
  end
end
