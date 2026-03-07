class AddPhotoUrlToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :photo_url, :string
  end
end
