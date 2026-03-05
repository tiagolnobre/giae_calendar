class CreateGiaeSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :giae_sessions do |t|
      t.references :user, null: false, foreign_key: true

      # Session data (encrypted)
      t.text :session_cookie_ciphertext

      # State machine
      t.integer :status, default: 0, null: false
      t.string :error_message

      # Concurrency control (only valid when status=refreshing)
      t.string :lock_key
      t.datetime :locked_at
      t.string :locked_by

      # Timestamps - context depends on state
      t.datetime :obtained_at
      t.datetime :expires_at
      t.datetime :last_used_at
      t.datetime :refreshed_at

      t.timestamps
    end

    add_index :giae_sessions, [ :user_id, :status ]
    add_index :giae_sessions, :lock_key, unique: true, where: "lock_key IS NOT NULL"
    add_index :giae_sessions, :expires_at
    add_index :giae_sessions, :updated_at
  end
end
