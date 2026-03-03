# frozen_string_literal: true

class RenameEncryptedPasswordToPasswordDigest < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :encrypted_password, :password_digest
  end
end
