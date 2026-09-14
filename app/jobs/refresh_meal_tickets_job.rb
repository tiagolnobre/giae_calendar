# frozen_string_literal: true

class RefreshMealTicketsJob < ApplicationScraperJob
  queue_as :default

  # Discard job if one is already running for this child
  around_enqueue do |job, block|
    child = job.arguments.first
    child_id = child.is_a?(Child) ? child.id : child
    key = "refresh_meal_tickets_#{child_id}"

    if Rails.cache.exist?(key)
      Rails.logger.info "[RefreshMealTicketsJob] Job already running for child #{child_id}, skipping"
      next
    end

    Rails.cache.write(key, true, expires_in: 10.minutes)
    begin
      block.call
    ensure
      Rails.cache.delete(key)
    end
  end

  def perform(child)
    child = child.is_a?(Child) ? child : Child.find(child)

    Rails.logger.info "[RefreshMealTicketsJob] Starting refresh for child #{child.id}"

    with_session(child) do |scraper|
      results = scraper.fetch_refeicoes_compra

      begin
        meal_details = scraper.fetch_meal_details
      rescue => e
        Rails.logger.warn "[RefreshMealTicketsJob] Failed to fetch meal details: #{e.message}"
        meal_details = {}
      end

      ActiveRecord::Base.transaction do
        results.each do |result|
          ticket = MealTicket.find_or_initialize_by(
            child: child,
            date: result[:date]
          )
          ticket.user = child.user
          ticket.bought = result[:bought]
          ticket.dish_type = result[:dish_type]
          ticket.save!

          if meal_details[result[:date]]
            detail = MealDetail.find_or_initialize_by(
              child: child,
              date: result[:date],
              period: meal_details[result[:date]][:descricaoperiodo] || "Almoço"
            )
            detail.user = child.user
            detail.soup = meal_details[result[:date]][:soup]
            detail.main_dish = meal_details[result[:date]][:main_dish]
            detail.vegetables = meal_details[result[:date]][:vegetables]
            detail.dessert = meal_details[result[:date]][:dessert]
            detail.bread = meal_details[result[:date]][:bread]
            detail.save!
          end
        end
      end

      child.update!(last_refreshed_at: Time.current)

      NotificationService.new(child.user).notify(
        "Refresh Complete",
        "Your meal tickets have been updated",
        types: [ :web_push ],
        child: child
      )

      Rails.logger.info "[RefreshMealTicketsJob] Completed refresh for child #{child.id}, #{results.length} tickets processed"

      results
    end
  rescue GiaeSessionManager::SessionUnavailable => e
    Rails.logger.info "[RefreshMealTicketsJob] Session unavailable for child #{child.id}: #{e.message}, will retry"
    raise
  end
end