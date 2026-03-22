# frozen_string_literal: true

require "test_helper"

class FetchSaldoDisponivelJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @job = FetchSaldoDisponivelJob.new
    # Use a real cache for these tests since around_enqueue uses Rails.cache
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "job is enqueued with correct queue" do
    assert_equal "default", FetchSaldoDisponivelJob.queue_name
  end

  test "around_enqueue prevents duplicate jobs for same user" do
    # First job should enqueue
    assert_enqueued_with(job: FetchSaldoDisponivelJob, args: [ @user ]) do
      FetchSaldoDisponivelJob.perform_later(@user)
    end

    # Set the cache key to simulate running job
    Rails.cache.write("fetch_saldo_#{@user.id}", true)

    # Second job should be skipped
    assert_no_enqueued_jobs do
      FetchSaldoDisponivelJob.perform_later(@user)
    end
  end

  test "perform creates saldo record when session is available" do
    # Create mock scraper that returns saldo data
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_saldo_disponivel).returns({
      euros: "25.50",
      cents: 2550
    })

    # Mock the session manager
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)

    GiaeSessionManager.stubs(:new).with(@user).returns(mock_session_manager)

    assert_difference "SaldoRecord.count", 1 do
      @job.perform(@user)
    end

    record = SaldoRecord.last
    assert_equal @user.id, record.user_id
    assert_equal 2550, record.cents
  end

  test "perform handles integer user id" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_saldo_disponivel).returns({
      euros: "10.00",
      cents: 1000
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_difference "SaldoRecord.count", 1 do
      @job.perform(@user.id)
    end
  end

  test "perform logs job completion" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_saldo_disponivel).returns({
      euros: "15.75",
      cents: 1575
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_logs_match(/FetchSaldoDisponivelJob.*Completed.*15.75.*1575 cents/) do
      @job.perform(@user)
    end
  end

  test "perform re-raises SessionUnavailable error" do
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).raises(GiaeSessionManager::SessionUnavailable, "Session expired")
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end

  test "perform logs session unavailable errors" do
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).raises(GiaeSessionManager::SessionUnavailable, "Session expired")
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_logs_match(/FetchSaldoDisponivelJob.*Session unavailable.*Session expired/) do
      assert_raises(GiaeSessionManager::SessionUnavailable) do
        @job.perform(@user)
      end
    end
  end

  test "perform logs unexpected errors" do
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).raises(StandardError, "Unexpected error")
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_logs_match(/FetchSaldoDisponivelJob.*Error.*StandardError.*Unexpected error/) do
      assert_raises(StandardError) do
        @job.perform(@user)
      end
    end
  end

  private

  def assert_logs_match(pattern)
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield

    assert_match pattern, log_output.string
  ensure
    Rails.logger = old_logger
  end
end
