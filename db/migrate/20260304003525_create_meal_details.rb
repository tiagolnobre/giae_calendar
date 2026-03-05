class CreateMealDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_details do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.string :period, null: false
      t.string :soup
      t.string :main_dish
      t.string :vegetables
      t.string :dessert
      t.string :bread

      t.timestamps
    end

    add_index :meal_details, [ :user_id, :date ], unique: true
  end
end
