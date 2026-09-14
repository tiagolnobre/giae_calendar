class EnableMultipleChildren < ActiveRecord::Migration[8.1]
  def change
    # The user_id + date/label/status unique indexes prevent multiple children
    # of the same family from sharing dates. Uniqueness is now enforced at the
    # child + date/label level (partial unique indexes added when child_id was
    # introduced). Keep the user-scoped indexes as plain (non-unique) indexes
    # for querying by the owning user.
    remove_index :meal_tickets, name: "index_meal_tickets_on_user_id_and_date"
    remove_index :meal_details, name: "index_meal_details_on_user_id_and_date"
    remove_index :school_years, name: "index_school_years_on_user_id_and_label"

    add_index :meal_tickets, [ :user_id, :date ], name: "index_meal_tickets_on_user_id_and_date"
    add_index :meal_details, [ :user_id, :date ], name: "index_meal_details_on_user_id_and_date"
    add_index :school_years, [ :user_id, :label ], name: "index_school_years_on_user_id_and_label"

    # Enforce referential integrity between child-scoped data and children.
    add_foreign_key :meal_tickets, :children, column: :child_id
    add_foreign_key :meal_details, :children, column: :child_id
    add_foreign_key :saldo_records, :children, column: :child_id
    add_foreign_key :school_years, :children, column: :child_id
    # Cascade so deleting a child removes all their sessions at DB level.
    # The app uses has_one :giae_session (destroys only the first row), so a
    # restrict FK would fail when multiple rows exist.
    add_foreign_key :giae_sessions, :children, column: :child_id, on_delete: :cascade
    add_foreign_key :notifications, :children, column: :child_id
  end
end