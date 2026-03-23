# frozen_string_literal: true

class ApplicationScraperJob < ApplicationJob
  queue_as :default

  # Retry on session unavailable (locked by another job) - fixed 10 second intervals
  retry_on GiaeSessionManager::SessionUnavailable,
    wait: 10.seconds,
    attempts: 10,
    jitter: 0

  # Retry on session expired - will trigger re-login
  retry_on GiaeScraperService::SessionExpired,
    wait: 10.seconds,
    attempts: 5,
    jitter: 0

  # Retry on login errors (might be rate limited)
  retry_on GiaeScraperService::LoginError,
    wait: 30.seconds,
    attempts: 3,
    jitter: 0

  # Retry on access denied (will trigger re-login)
  retry_on GiaeScraperService::AccessDenied,
    wait: 10.seconds,
    attempts: 5,
    jitter: 0

  protected

  def with_session(user)
    GiaeSessionManager.new(user).with_active_session { |scraper| yield scraper }
  end
end
