class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :in_app_notifications_enabled, :boolean, default: true
    add_column :users, :email_notifications_enabled, :boolean, default: true
  end
end
