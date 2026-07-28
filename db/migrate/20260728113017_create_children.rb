class CreateChildren < ActiveRecord::Migration[8.1]
  def change
    create_table :children do |t|
      t.references :user, null: false, foreign_key: true

      t.string :giae_username
      t.text :giae_username_ciphertext
      t.string :giae_password
      t.text :giae_password_ciphertext
      t.string :giae_school_code

      t.string :nome_utilizador
      t.string :nome_escola
      t.text :photo_data

      t.datetime :last_refreshed_at

      t.timestamps
    end

    up_only do
      execute <<-SQL
        INSERT INTO children (user_id, giae_username, giae_username_ciphertext, giae_password, giae_password_ciphertext, giae_school_code, nome_utilizador, nome_escola, photo_data, last_refreshed_at, created_at, updated_at)
        SELECT id, giae_username, giae_username_ciphertext, giae_password, giae_password_ciphertext, COALESCE(giae_school_code, '161676'), nome_utilizador, nome_escola, photo_data, last_refreshed_at, datetime('now'), datetime('now')
        FROM users
        WHERE giae_username IS NOT NULL
      SQL
    end
  end
end
