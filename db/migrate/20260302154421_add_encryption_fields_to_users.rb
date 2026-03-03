# frozen_string_literal: true

class AddEncryptionFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :giae_username_ciphertext, :text
    add_column :users, :giae_password_ciphertext, :text
  end
end
