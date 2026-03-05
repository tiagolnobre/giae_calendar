class AddGiaeSchoolCodeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :giae_school_code, :string
  end
end
