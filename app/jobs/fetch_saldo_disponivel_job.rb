# frozen_string_literal: true

class FetchSaldoDisponivelJob < ApplicationScraperJob
  queue_as :default

  around_enqueue do |job, block|
    child = job.arguments.first
    child_id = child.is_a?(Child) ? child.id : child
    key = "fetch_saldo_#{child_id}"

    if Rails.cache.exist?(key)
      Rails.logger.info "[FetchSaldoDisponivelJob] Job already running for child #{child_id}, skipping"
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
    GiaeDebug.log("FetchSaldoDisponivelJob started", { child_id: child.id, job_id: job_id })
    GiaeDebug.log("Child found", { child_id: child.id, username: child.giae_username })

    Rails.logger.info "[FetchSaldoDisponivelJob] Starting for child #{child.id}"

    with_session(child) do |scraper|
      GiaeDebug.log("In with_session block, about to fetch saldo")

      result = scraper.fetch_saldo_disponivel
      GiaeDebug.log("Saldo fetched successfully", result)

      SaldoRecord.create!(
        user: child.user,
        child: child,
        cents: result[:cents]
      )
      GiaeDebug.log("SaldoRecord created")

      Rails.logger.info "[FetchSaldoDisponivelJob] Completed for child #{child.id}, saldo: #{result[:euros]} (#{result[:cents]} cents)"

      result
    end
  rescue GiaeSessionManager::SessionUnavailable => e
    GiaeDebug.log_error("SessionUnavailable error", e)
    Rails.logger.info "[FetchSaldoDisponivelJob] Session unavailable for child #{child.id}: #{e.message}, will retry"
    raise
  rescue => e
    GiaeDebug.log_error("Unexpected error in job", e)
    Rails.logger.error "[FetchSaldoDisponivelJob] Error for child #{child.id}: #{e.class}: #{e.message}"
    raise
  end
end