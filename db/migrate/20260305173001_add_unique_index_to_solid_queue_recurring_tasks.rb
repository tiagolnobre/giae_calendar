class AddUniqueIndexToSolidQueueRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    add_index :solid_queue_recurring_tasks, :key, unique: true
  end
end
