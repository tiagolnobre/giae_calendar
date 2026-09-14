# frozen_string_literal: true

class RefreshStaleMealTicketsJob < ApplicationJob
  queue_as :default

  STALE_HOURS = ENV.fetch("MEAL_TICKETS_STALE_HOURS", 4).to_i

  def perform
    children = Child.where(
      "last_refreshed_at < ? OR last_refreshed_at IS NULL",
      STALE_HOURS.hours.ago
    )

    Rails.logger.info "[RefreshStaleMealTicketsJob] Found #{children.count} children with stale data"

    children.find_each do |child|
      RefreshMealTicketsJob.perform_later(child.id)
    end
  end
end