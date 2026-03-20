# frozen_string_literal: true

require "test_helper"

class FetchSaldoDisponivelJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @job = FetchSaldoDisponivelJob.new
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

  test "perform handles user passed as User object" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "25.50",
      cents: 2550
    })

    @job.expects(:with_session).with(@user).yields(mock_scraper)

    assert_difference "SaldoRecord.count", 1 do
      result = @job.perform(@user)
      assert_equal 2550, result[:cents]
      assert_equal "25.50", result[:euros]
    end

    record = SaldoRecord.last
    assert_equal @user.id, record.user_id
    assert_equal 2550, record.cents
  end

  test "perform handles user passed as integer id" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "10.00",
      cents: 1000
    })

    @job.expects(:with_session).with(@user).yields(mock_scraper)

    assert_difference "SaldoRecord.count", 1 do
      @job.perform(@user.id)
    end
  end

  test "perform creates saldo record with correct data" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "31.66",
      cents: 3166
    })

    @job.expects(:with_session).with(@user).yields(mock_scraper)

    @job.perform(@user)

    record = SaldoRecord.last
    assert_equal 3166, record.cents
    assert_equal @user.id, record.user_id
  end

  test "perform logs job completion" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_saldo_disponivel).returns({
      euros: "15.75",
      cents: 1575
    })

    @job.expects(:with_session).with(@user).yields(mock_scraper)

    assert_logs_match(/FetchSaldoDisponivelJob.*Completed.*15.75.*1575 cents/) do
      @job.perform(@user)
    end
  end

  test "perform re-raises SessionUnavailable error" do
    @job.expects(:with_session).with(@user).raises(GiaeSessionManager::SessionUnavailable, "Session expired")

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end

  test "perform logs session unavailable errors" do
    @job.expects(:with_session).with(@user).raises(GiaeSessionManager::SessionUnavailable, "Session expired")

    assert_logs_match(/FetchSaldoDisponivelJob.*Session unavailable.*Session expired/) do
      assert_raises(GiaeSessionManager::SessionUnavailable) do
        @job.perform(@user)
      end
    end
  end

  test "perform logs unexpected errors" do
    @job.expects(:with_session).with(@user).raises(StandardError, "Unexpected error")

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
