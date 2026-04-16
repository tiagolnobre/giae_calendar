# frozen_string_literal: true

class NotifyUpcomingMealTicketsJob < ApplicationJob
  queue_as :default

  def perform
    tomorrow = Date.tomorrow

    User.find_each do |user|
      next unless user.in_app_notifications_enabled? || user.email_notifications_enabled? || user.push_subscriptions.any?

      begin
        has_ticket = user.meal_tickets.exists?(date: tomorrow, bought: true)

        if has_ticket
          notify_user_with_menu(user, tomorrow)
        else
          Rails.logger.info "[NotifyUpcomingMealTicketsJob] User #{user.id} has no ticket for tomorrow"
          notify_user_no_ticket(user, tomorrow)
        end
      rescue => e
        Rails.logger.error "[NotifyUpcomingMealTicketsJob] Failed for user #{user.id}: #{e.class} - #{e.message}"
      end
    end
  end

  private

  def notify_user_no_ticket(user, tomorrow)
    title = I18n.t("calendar.no_ticket_reminder")
    body = I18n.t("calendar.no_ticket_body", date: tomorrow.strftime("%d de %B"))
    send_notification(user, title, body)
  end

  def notify_user_with_menu(user, tomorrow)
    meal_detail = user.meal_details.find_by(date: tomorrow)
    return unless meal_detail&.main_dish.present?

    title = I18n.t("calendar.tomorrow_menu")
    body = I18n.t("calendar.tomorrow_menu_body", dish: meal_detail.main_dish)
    send_notification(user, title, body)
  end

  def send_notification(user, title, body)
    notification_types = []
    notification_types << :in_app if user.in_app_notifications_enabled?
    notification_types << :email if user.email_notifications_enabled?
    notification_types << :web_push if user.push_subscriptions.any?

    NotificationService.new(user).notify(title, body, types: notification_types)
  end
end
