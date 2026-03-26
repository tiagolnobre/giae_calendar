# frozen_string_literal: true

class NotifyUpcomingMealTicketsJob < ApplicationJob
  queue_as :default

  def perform
    tomorrow = Date.tomorrow

    User.find_each do |user|
      next unless user.in_app_notifications_enabled? || user.email_notifications_enabled? || user.push_subscriptions.any?

      has_ticket = user.meal_tickets.exists?(date: tomorrow, bought: true)

      unless has_ticket
        Rails.logger.info "[NotifyUpcomingMealTicketsJob] User #{user.id} has no ticket for tomorrow"
        notify_user(user, tomorrow)
      end
    end
  end

  private

  def notify_user(user, tomorrow)
    title = "Lembrete: Refeição de amanhã"
    body = "Ainda não comprou a refeição para #{tomorrow.strftime("%d de %B")}. Clique para ver os detalhes."

    notification_types = []
    notification_types << :in_app if user.in_app_notifications_enabled?
    notification_types << :email if user.email_notifications_enabled?
    notification_types << :web_push if user.push_subscriptions.any?

    NotificationService.new(user).notify(title, body, types: notification_types)
  end
end
