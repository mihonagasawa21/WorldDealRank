class AddTitleAndCountryToPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :posts, :title, :string, null: false
    add_reference :posts, :country, foreign_key: true
  end
end