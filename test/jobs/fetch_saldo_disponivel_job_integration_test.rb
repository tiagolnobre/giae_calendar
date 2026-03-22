# frozen_string_literal: true

require "test_helper"

class FetchSaldoDisponivelJobIntegrationTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )
    @job = FetchSaldoDisponivelJob.new
    # Use a real cache for these tests since around_enqueue uses Rails.cache
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "around_enqueue prevents duplicate jobs" do
    # First enqueue should succeed
    assert_enqueued_with(job: FetchSaldoDisponivelJob) do
      FetchSaldoDisponivelJob.perform_later(@user)
    end

    # Simulate job in progress
    Rails.cache.write("fetch_saldo_#{@user.id}", true)

    # Second enqueue should be skipped
    assert_no_enqueued_jobs do
      FetchSaldoDisponivelJob.perform_later(@user)
    end

    Rails.cache.delete("fetch_saldo_#{@user.id}")
  end

  test "around_enqueue cleans up cache on success" do
    FetchSaldoDisponivelJob.perform_later(@user)
    assert Rails.cache.exist?("fetch_saldo_#{@user.id}")

    perform_enqueued_jobs
    assert_not Rails.cache.exist?("fetch_saldo_#{@user.id}")
  end

  test "around_enqueue cleans up cache on failure" do
    FetchSaldoDisponivelJob.perform_later(@user)

    # Simulate job failure
    FetchSaldoDisponivelJob.any_instance.stubs(:perform).raises(StandardError)

    begin
      perform_enqueued_jobs
    rescue
      # Expected
    end

    assert_not Rails.cache.exist?("fetch_saldo_#{@user.id}")
  end

  test "job handles integer user id" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "25.50",
      cents: 2550
    })

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_difference "SaldoRecord.count", 1 do
      @job.perform(@user.id)
    end
  end

  test "job handles User object" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "31.66",
      cents: 3166
    })

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_difference "SaldoRecord.count", 1 do
      result = @job.perform(@user)
      assert_equal 3166, result[:cents]
      assert_equal "31.66", result[:euros]
    end
  end

  test "job creates saldo record with correct data" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "15.75",
      cents: 1575
    })

    GiaeScraperService.expects(:new).returns(mock_scraper)

    @job.perform(@user)

    record = SaldoRecord.last
    assert_equal @user.id, record.user_id
    assert_equal 1575, record.cents
  end

  test "job handles session unavailable" do
    GiaeSessionManager.any_instance.expects(:with_active_session).raises(
      GiaeSessionManager::SessionUnavailable, "Session expired"
    )

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end

  test "job logs completion" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "20.00",
      cents: 2000
    })

    GiaeScraperService.expects(:new).returns(mock_scraper)

    # Capture logs
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    @job.perform(@user)

    assert_match(/FetchSaldoDisponivelJob.*Completed/, log_output.string)
  ensure
    Rails.logger = old_logger
  end

  test "job logs session unavailable errors" do
    GiaeSessionManager.any_instance.expects(:with_active_session).raises(
      GiaeSessionManager::SessionUnavailable, "Session expired"
    )

    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end

    assert_match(/Session unavailable.*Session expired/, log_output.string)
  ensure
    Rails.logger = old_logger
  end

  test "job logs unexpected errors" do
    GiaeSessionManager.any_instance.expects(:with_active_session).raises(
      StandardError, "Unexpected error"
    )

    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    assert_raises(StandardError) do
      @job.perform(@user)
    end

    assert_match(/FetchSaldoDisponivelJob.*Error.*StandardError.*Unexpected error/, log_output.string)
  ensure
    Rails.logger = old_logger
  end
end
