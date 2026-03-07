# frozen_string_literal: true

class AddUniqueMofaCodeToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :mofa_code, :string unless column_exists?(:countries, :mofa_code)

    # 既存データで mofa_code が重複/NULLだと unique が貼れないので
    # NULL を許容したまま、値があるものだけユニークにする（SQLiteでもOK）
    add_index :countries, :mofa_code, unique: true
  end
end