class AddKindAndParentToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :kind, :integer, null: false, default: 0
    add_column :countries, :parent_country_id, :integer
    add_index :countries, :kind
    add_index :countries, :parent_country_id
  end
end