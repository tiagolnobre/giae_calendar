# frozen_string_literal: true

class RefreshStaleMealTicketsJob < ApplicationJob
  queue_as :default

  STALE_HOURS = ENV.fetch("MEAL_TICKETS_STALE_HOURS", 4).to_i

  def perform
    users = User.where(
      "last_refreshed_at < ? OR last_refreshed_at IS NULL",
      STALE_HOURS.hours.ago
    )

    Rails.logger.info "[RefreshStaleMealTicketsJob] Found #{users.count} users with stale data"

    users.find_each do |user|
      RefreshMealTicketsJob.perform_later(user.id)
    end

    NotifyUpcomingMealTicketsJob.perform_later(wait: 10.minutes)
  end
end
