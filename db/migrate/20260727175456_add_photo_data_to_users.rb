class AddPhotoDataToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :photo_data, :text
  end
end
