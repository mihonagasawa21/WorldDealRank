# frozen_string_literal: true

class AddSafetyMaxLevelToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :safety_max_level, :integer
    add_index  :countries, :safety_max_level
  end
end
