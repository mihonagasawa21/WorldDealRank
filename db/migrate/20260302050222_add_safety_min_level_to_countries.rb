class AddSafetyMinLevelToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :safety_min_level, :integer
  end
end
