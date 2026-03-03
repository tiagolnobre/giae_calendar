# frozen_string_literal: true

class AddDishTypeToMealTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :meal_tickets, :dish_type, :string
    add_index :meal_tickets, :dish_type
  end
end
