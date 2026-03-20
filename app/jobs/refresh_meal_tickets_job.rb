# frozen_string_literal: true

class RefreshMealTicketsJob < ApplicationScraperJob
  queue_as :default

  # Discard job if one is already running for this user
  around_enqueue do |job, block|
    user = job.arguments.first
    user_id = user.is_a?(User) ? user.id : user
    key = "refresh_meal_tickets_#{user_id}"

    if Rails.cache.exist?(key)
      Rails.logger.info "[RefreshMealTicketsJob] Job already running for user #{user_id}, skipping"
      next
    end

    Rails.cache.write(key, true, expires_in: 10.minutes)
    begin
      block.call
    ensure
      Rails.cache.delete(key)
    end
  end

  def perform(user)
    user = user.is_a?(User) ? user : User.find(user)

    Rails.logger.info "[RefreshMealTicketsJob] Starting refresh for user #{user.id}"

    with_session(user) do |scraper|
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
            user_id: user.id,
            date: result[:date]
          )
          ticket.bought = result[:bought]
          ticket.dish_type = result[:dish_type]
          ticket.save!

          if meal_details[result[:date]]
            detail = MealDetail.find_or_initialize_by(
              user_id: user.id,
              date: result[:date],
              period: meal_details[result[:date]][:descricaoperiodo] || "Almoço"
            )
            detail.soup = meal_details[result[:date]][:soup]
            detail.main_dish = meal_details[result[:date]][:main_dish]
            detail.vegetables = meal_details[result[:date]][:vegetables]
            detail.dessert = meal_details[result[:date]][:dessert]
            detail.bread = meal_details[result[:date]][:bread]
            detail.save!
          end
        end
      end

      user.update!(last_refreshed_at: Time.current)

      Rails.logger.info "[RefreshMealTicketsJob] Completed refresh for user #{user.id}, #{results.length} tickets processed"

      results
    end
  rescue GiaeSessionManager::SessionUnavailable => e
    Rails.logger.info "[RefreshMealTicketsJob] Session unavailable for user #{user.id}: #{e.message}, will retry"
    raise
  end
end
