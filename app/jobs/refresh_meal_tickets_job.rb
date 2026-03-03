# frozen_string_literal: true

class RefreshMealTicketsJob < ApplicationJob
  queue_as :default

  # No automatic retries - let it fail and user can manually retry
  # retry_on StandardError, wait: 30.seconds, attempts: 3

  # Discard job if one is already running for this user
  around_enqueue do |job, block|
    user_id = job.arguments.first
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

  def perform(user_id)
    user = User.find(user_id)

    Rails.logger.info "[RefreshMealTicketsJob] Starting refresh for user #{user.id}"

    scraper = GiaeScraperService.new(
      username: user.giae_username,
      password: user.giae_password,
      login_url: Rails.application.config.giae_login_url,
      headless: true
    )

    results = scraper.call

    ActiveRecord::Base.transaction do
      results.each do |result|
        ticket = MealTicket.find_or_initialize_by(
          user_id: user.id,
          date: result[:date]
        )
        ticket.bought = result[:bought]
        ticket.dish_type = result[:dish_type]
        ticket.save!
      end
    end

    user.update!(last_refreshed_at: Time.current)

    Rails.logger.info "[RefreshMealTicketsJob] Completed refresh for user #{user.id}, #{results.length} tickets processed"

    results
  rescue => e
    Rails.logger.error "[RefreshMealTicketsJob] Failed for user #{user_id}: #{e.message}"
    raise
  end
end
