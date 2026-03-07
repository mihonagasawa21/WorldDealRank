class AddSafetyFieldsToCountries < ActiveRecord::Migration[7.2]
  def change
    # iso3 が無い場合だけ追加（すでにあるならこの行は削除でOK）
    add_column :countries, :iso3, :string unless column_exists?(:countries, :iso3)

    # MOFAコードは "1000" のように文字列で持つ（先頭ゼロがあり得るため）
    change_column :countries, :mofa_country_code, :string

    add_column :countries, :safety_risk_level, :integer, null: false, default: 0
    add_column :countries, :safety_infection_level, :integer, null: false, default: 0
    add_column :countries, :safety_source_updated_at, :datetime
    add_column :countries, :safety_fetched_at, :datetime

    add_index :countries, :iso3
    add_index :countries, :mofa_country_code
  end
end