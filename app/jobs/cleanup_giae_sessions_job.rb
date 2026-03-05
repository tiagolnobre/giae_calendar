# frozen_string_literal: true

class CleanupGiaeSessionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CleanupGiaeSessionsJob] Starting cleanup"

    # Delete sessions older than 24 hours
    old_count = GiaeSession.where("updated_at < ?", 24.hours.ago).destroy_all.count
    Rails.logger.info "[CleanupGiaeSessionsJob] Deleted #{old_count} old sessions"

    # Reset stuck refreshing sessions (locked for more than lock timeout)
    stuck_count = GiaeSession.where(status: :refreshing)
      .where("locked_at < ?", GiaeSessionManager::LOCK_TIMEOUT.ago)
      .count

    GiaeSession.where(status: :refreshing)
      .where("locked_at < ?", GiaeSessionManager::LOCK_TIMEOUT.ago)
      .find_each do |session|
      session.transition_to_failed!("Lock timed out after #{GiaeSessionManager::LOCK_TIMEOUT}s")
      Rails.logger.warn "[CleanupGiaeSessionsJob] Reset stuck session for user #{session.user_id}"
    end

    Rails.logger.info "[CleanupGiaeSessionsJob] Reset #{stuck_count} stuck sessions"
    Rails.logger.info "[CleanupGiaeSessionsJob] Cleanup complete"
  end
end
