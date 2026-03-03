class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :body
      t.references :notifiable, polymorphic: true, null: true
      t.datetime :read_at
      t.integer :notification_type, default: 0

      t.timestamps
    end

    add_column :users, :in_app_notifications_enabled, :boolean, default: true
    add_column :users, :email_notifications_enabled, :boolean, default: true
  end
end
