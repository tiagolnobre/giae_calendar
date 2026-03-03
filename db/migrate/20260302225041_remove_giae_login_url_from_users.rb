class RemoveGiaeLoginUrlFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :giae_login_url, :string
  end
end
