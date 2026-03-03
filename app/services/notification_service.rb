# frozen_string_literal: true

class NotificationService
  def initialize(user)
    @user = user
  end

  def notify(title, body, notifiable: nil, types: nil)
    types ||= default_notification_types

    types.each do |type|
      case type
      when :in_app
        create_in_app_notification(title, body, notifiable) if @user.in_app_notifications_enabled?
      when :email
        send_email_notification(title, body, notifiable) if @user.email_notifications_enabled?
      end
    end
  end

  private

  def default_notification_types
    [ :in_app ]
  end

  def create_in_app_notification(title, body, notifiable)
    @user.notifications.create!(
      title: title,
      body: body,
      notifiable: notifiable,
      notification_type: :in_app
    )
  end

  def send_email_notification(title, body, notifiable)
    @user.notifications.create!(
      title: title,
      body: body,
      notifiable: notifiable,
      notification_type: :email
    )

    UserMailer.notification_email(@user, title, body).deliver_later
  end
end
