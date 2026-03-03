# frozen_string_literal: true

class CreateSaldoRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :saldo_records do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :cents, null: false

      t.timestamps
    end

    add_index :saldo_records, :user_id
  end
end
