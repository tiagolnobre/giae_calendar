class AddRememberTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :remember_token, :string
    add_column :users, :remember_created_at, :datetime
  end
end
