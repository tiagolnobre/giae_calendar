# frozen_string_literal: true

class AddIndexesToSaldoRecords < ActiveRecord::Migration[8.1]
  def change
    add_index :saldo_records, [ :user_id, :created_at ], name: "index_saldo_records_on_user_id_and_created_at"
  end
end
