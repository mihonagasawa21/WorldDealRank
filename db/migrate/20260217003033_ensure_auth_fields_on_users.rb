class EnsureAuthFieldsOnUsers < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:users, :password_digest)
      add_column :users, :password_digest, :string
    end

    unless column_exists?(:users, :verified)
      add_column :users, :verified, :boolean, null: false, default: false
    end
  end
end
