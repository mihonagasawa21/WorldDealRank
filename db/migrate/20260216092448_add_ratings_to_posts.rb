class AddRatingsToPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :posts, :overall, :integer
    add_column :posts, :level, :integer
  end
end
