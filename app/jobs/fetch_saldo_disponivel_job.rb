# frozen_string_literal: true

class FetchSaldoDisponivelJob < ApplicationJob
  queue_as :default

  around_enqueue do |job, block|
    user_id = job.arguments.first
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

  def perform(user_id)
    user = User.find(user_id)

    Rails.logger.info "[FetchSaldoDisponivelJob] Starting for user #{user.id}"

    scraper = GiaeScraperService.new(
      username: user.giae_username,
      password: user.giae_password,
      login_url: Rails.application.config.giae_login_url,
      headless: true
    )

    scraper.login!
    result = scraper.fetch_saldo_disponivel

    SaldoRecord.create!(
      user_id: user.id,
      cents: result[:cents]
    )

    Rails.logger.info "[FetchSaldoDisponivelJob] Completed for user #{user.id}, saldo: #{result[:euros]} (#{result[:cents]} cents)"

    result
  rescue => e
    Rails.logger.error "[FetchSaldoDisponivelJob] Failed for user #{user_id}: #{e.message}"
    raise
  ensure
    scraper&.instance_variable_get(:@browser)&.quit
  end
end
