class CreateMealTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.boolean :bought

      t.timestamps
    end

    add_index :meal_tickets, [ :user_id, :date ], unique: true
  end
end
