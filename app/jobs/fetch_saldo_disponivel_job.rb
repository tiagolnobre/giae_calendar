# frozen_string_literal: true

class FetchSaldoDisponivelJob < ApplicationScraperJob
  queue_as :default

  around_enqueue do |job, block|
    user = job.arguments.first
    user_id = user.is_a?(User) ? user.id : user
    key = "fetch_saldo_#{user_id}"

    if Rails.cache.exist?(key)
      Rails.logger.info "[FetchSaldoDisponivelJob] Job already running for user #{user_id}, skipping"
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
    GiaeDebug.log("FetchSaldoDisponivelJob started", { user_id: user.id, job_id: job_id })
    GiaeDebug.log("User found", { user_id: user.id, username: user.giae_username })

    Rails.logger.info "[FetchSaldoDisponivelJob] Starting for user #{user.id}"

    with_session(user) do |scraper|
      GiaeDebug.log("In with_session block, about to fetch saldo")

      result = scraper.fetch_saldo_disponivel
      GiaeDebug.log("Saldo fetched successfully", result)

      SaldoRecord.create!(
        user_id: user.id,
        cents: result[:cents]
      )
      GiaeDebug.log("SaldoRecord created")

      Rails.logger.info "[FetchSaldoDisponivelJob] Completed for user #{user.id}, saldo: #{result[:euros]} (#{result[:cents]} cents)"

      result
    end
  rescue GiaeSessionManager::SessionUnavailable => e
    GiaeDebug.log_error("SessionUnavailable error", e)
    Rails.logger.info "[FetchSaldoDisponivelJob] Session unavailable for user #{user.id}: #{e.message}, will retry"
    raise
  rescue => e
    GiaeDebug.log_error("Unexpected error in job", e)
    Rails.logger.error "[FetchSaldoDisponivelJob] Error for user #{user.id}: #{e.class}: #{e.message}"
    raise
  end
end
