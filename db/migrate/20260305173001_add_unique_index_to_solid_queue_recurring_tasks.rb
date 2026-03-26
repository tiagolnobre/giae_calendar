class AddUniqueIndexToSolidQueueRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    unless index_exists?(:solid_queue_recurring_tasks, :key, unique: true)
      add_index :solid_queue_recurring_tasks, :key, unique: true
    end
  end
end
