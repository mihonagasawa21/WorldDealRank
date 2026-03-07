class CreateCountries < ActiveRecord::Migration[7.0]
  def change
    create_table :countries do |t|
      t.string :name_ja, null: false
      t.string :name_en

      t.string :mofa_country_code, null: false
      t.string :iso2
      t.string :iso3
      t.string :currency_code

      t.integer :safety_level
      t.datetime :safety_updated_at

      t.decimal :tourism_coef, precision: 10, scale: 4, default: 1.0, null: false

      t.decimal :fx_rate_usd, precision: 20, scale: 10
      t.date :fx_date

      t.decimal :ppp_lcu_per_intl, precision: 20, scale: 10
      t.integer :ppp_year

      t.decimal :plr, precision: 20, scale: 10
      t.decimal :final_index, precision: 20, scale: 10
      t.decimal :deviation_pct, precision: 20, scale: 10

      t.datetime :calculated_at
      t.text :last_error

      t.timestamps
    end

    add_index :countries, :mofa_country_code, unique: true
    add_index :countries, :iso2
    add_index :countries, :currency_code
    add_index :countries, :safety_level
    add_index :countries, :final_index
  end
end
