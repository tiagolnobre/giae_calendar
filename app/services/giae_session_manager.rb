# frozen_string_literal: true

class GiaeSessionManager
  LOCK_TIMEOUT = 30.seconds

  class SessionUnavailable < StandardError; end

  def initialize(user)
    @user = user
  end

  # Main entry point for jobs
  # Yields a GiaeScraperService with an active session
  def with_active_session
    GiaeDebug.log("with_active_session started", { user_id: @user.id })

    session = acquire_or_refresh_session
    GiaeDebug.log("Session acquired", { session_id: session.id, status: session.status, refreshed_at: session.refreshed_at })

    # Check if session is too old (older than 24 hours)
    if session.refreshed_at && session.refreshed_at < 24.hours.ago
      GiaeDebug.log("Session is too old, marking as expired", { refreshed_at: session.refreshed_at })
      session.transition_to_expired!
      raise SessionUnavailable, "Session expired due to age"
    end

    scraper = create_scraper_with_session(session)
    GiaeDebug.log("Scraper created with session", { has_cookie: scraper.cookies.present? })

    begin
      result = yield scraper
      session.touch(:last_used_at)
      GiaeDebug.log("Request completed successfully")
      result
    rescue GiaeScraperService::SessionExpired => e
      session.transition_to_expired!
      GiaeDebug.log_error("Session expired during request", e)
      Rails.logger.warn "[GiaeSessionManager] Session expired during request for user #{@user.id}"
      raise SessionUnavailable, "Session expired, job will retry"
    rescue GiaeScraperService::AccessDenied => e
      session.transition_to_expired!
      GiaeDebug.log_error("Access denied during request", e)
      Rails.logger.warn "[GiaeSessionManager] Access denied for user #{@user.id}, forcing new session"
      raise SessionUnavailable, "Access denied, forcing new session"
    end
  end

  private

  def acquire_or_refresh_session
    ActiveRecord::Base.transaction do
      session = GiaeSession.lock("FOR UPDATE NOWAIT")
        .find_or_initialize_by(user: @user)

      case session.status
      when "active"
        # Check if session is too old (cookie expired)
        if session.refreshed_at && session.refreshed_at < 24.hours.ago
          GiaeDebug.log("Active session is too old, refreshing", { refreshed_at: session.refreshed_at })
          obtain_new_session!(session)
        end
        return session

      when "refreshing"
        # Another job is refreshing - check if lock is stale
        if session.locked_at && session.locked_at > LOCK_TIMEOUT.ago
          Rails.logger.info "[GiaeSessionManager] Session locked by #{session.locked_by} for user #{@user.id}"
          raise SessionUnavailable, "Session locked by another process"
        else
          # Stale lock, take over
          Rails.logger.info "[GiaeSessionManager] Taking over stale lock for user #{@user.id}"
          obtain_new_session!(session)
          return session
        end

      when "pending", "expired", "failed"
        # Need to obtain new session
        obtain_new_session!(session)
        return session
      end
    end
  rescue ActiveRecord::LockWaitTimeout
    Rails.logger.info "[GiaeSessionManager] Could not acquire lock for user #{@user.id}"
    raise SessionUnavailable, "Could not acquire session lock"
  end

  def obtain_new_session!(session)
    job_info = "#{self.class.name}-#{SecureRandom.hex(4)}"

    begin
      session.transition_to_refreshing!(locked_by: job_info)

      Rails.logger.info "[GiaeSessionManager] Logging in for user #{@user.id}"

      scraper = create_fresh_scraper
      scraper.login!

      session.reload  # Refresh lock
      session.transition_to_active!(scraper.cookies)

      Rails.logger.info "[GiaeSessionManager] Login successful for user #{@user.id}"
    rescue => e
      session.reload
      session.transition_to_failed!(e.message)
      Rails.logger.error "[GiaeSessionManager] Login failed for user #{@user.id}: #{e.message}"
      raise
    end
  end

  def create_fresh_scraper
    GiaeScraperService.new(
      username: @user.giae_username,
      password: @user.giae_password,
      login_url: Rails.application.config.giae_login_url,
      school_code: @user.giae_school_code
    )
  end

  def create_scraper_with_session(session)
    GiaeDebug.log("Creating scraper with session", { session_id: session.id, has_encrypted_cookie: session.session_cookie_ciphertext.present? })

    cookie = session.decrypt_cookie
    GiaeDebug.log("Cookie decrypted", { has_cookie: cookie.present?, cookie_length: cookie&.length })

    unless cookie
      Rails.logger.error "[GiaeSessionManager] Failed to decrypt cookie for user #{@user.id}"
      session.transition_to_expired!
      raise SessionUnavailable, "Session invalid"
    end

    GiaeScraperService.new(
      username: @user.giae_username,
      password: @user.giae_password,
      login_url: Rails.application.config.giae_login_url,
      school_code: @user.giae_school_code,
      session_cookie: cookie
    )
  end
end
