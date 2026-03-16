class RemoveTourismCoefFromCountries < ActiveRecord::Migration[7.2]
  def change
    remove_column :countries, :tourism_coef, :decimal
  end
end