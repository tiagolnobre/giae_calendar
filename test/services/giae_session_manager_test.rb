# frozen_string_literal: true

require "test_helper"

class GiaeSessionManagerTest < ActiveSupport::TestCase
  setup do
    @child = children(:one)
    @user = @child.user
    @manager = GiaeSessionManager.new(@child)
  end

  test "initialize stores child" do
    assert_equal @child, @manager.instance_variable_get(:@child)
  end

  test "LOCK_TIMEOUT constant is set to 30 seconds" do
    assert_equal 30.seconds, GiaeSessionManager::LOCK_TIMEOUT
  end

  test "SessionUnavailable is a StandardError" do
    assert GiaeSessionManager::SessionUnavailable < StandardError
  end

  test "with_active_session raises error when login fails" do
    # Delete any existing sessions for this child first
    GiaeSession.where(child: @child).delete_all

    # Create a pending session
    GiaeSession.create!(child: @child, status: :pending)

    # Stub cookie decryption to allow test to proceed to login attempt
    GiaeSession.any_instance.stubs(:decrypt_cookie).returns("valid_cookie")

    # Mock the scraper
    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!).raises(StandardError, "Login failed")

    # Stub GiaeScraperService.new to return our mock
    GiaeScraperService.expects(:new).returns(mock_scraper)

    error = assert_raises(StandardError) do
      @manager.with_active_session { |_| }
    end
    assert_match(/Login failed/, error.message)
  end

  test "with_active_session attempts to renew expired session" do
    GiaeSession.where(child: @child).delete_all

    # Create an expired session (recent, so the 24h age check does not fire first)
    GiaeSession.create!(
      child: @child,
      status: :expired,
      refreshed_at: 1.hour.ago
    )

    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    # Mock failed login attempt during renewal
    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!).raises(StandardError, "Login failed")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_raises(StandardError) do
      @manager.with_active_session { |_| }
    end

    # The login failure aborts the session transaction, so the renewal
    # (transition to refreshing) is rolled back and the session stays expired.
    session = GiaeSession.find_by(child: @child)
    assert_equal "expired", session.status
  end

  test "with_active_session handles session age check" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    # Create an old active session
    GiaeSession.create!(
      child: @child,
      status: :active,
      refreshed_at: 25.hours.ago,
      session_cookie_ciphertext: "test"
    )

    # Stub cookie decryption since we're testing the age check
    GiaeSession.any_instance.stubs(:decrypt_cookie).returns("valid_cookie")

    # Set up GIAE credentials
    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    # When session is old, obtain_new_session! is called which tries to login
    # The login will fail because there's no real GIAE connection
    assert_raises(GiaeScraperService::SessionExpired) do
      @manager.with_active_session { |_| }
    end
  end

  test "with_active_session uses valid active session" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    session = GiaeSession.create!(
      child: @child,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "encrypted_cookie"
    )

    # Stub cookie decryption
    GiaeSession.any_instance.stubs(:decrypt_cookie).returns("valid_cookie")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:login!)
    mock_scraper.stubs(:cookies).returns("valid_cookie")
    GiaeScraperService.stubs(:new).returns(mock_scraper)

    called = false
    @manager.with_active_session do |scraper|
      called = true
      assert_equal mock_scraper, scraper
    end

    assert called
    session.reload
    assert session.last_used_at.present?
  end

  test "with_active_session handles locked refreshing session" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :refreshing,
      locked_at: 10.seconds.ago,  # Lock is NOT stale (within 30 second timeout)
      locked_by: "other-job-123"
    )

    error = assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end

    assert_match(/Session locked by another process/, error.message)
  end

  test "with_active_session takes over stale lock" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :refreshing,
      locked_at: 2.minutes.ago,  # Lock IS stale (older than 30 second timeout)
      locked_by: "old-job-456"
    )

    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:login!)  # Use stubs to allow any number of calls
    mock_scraper.stubs(:cookies).returns("new_session_cookie")  # Use stubs for cookies too
    mock_scraper.stubs(:fetch_info).returns("nomeutilizador" => "Test User", "nomeescola" => "Test School")
    mock_scraper.stubs(:extract_guidutente_from_fotoutente).returns(nil)
    GiaeScraperService.stubs(:new).returns(mock_scraper)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(child: @child)
    assert_equal "active", session.status
  end

  test "with_active_session handles pending status" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :pending
    )

    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:login!)
    mock_scraper.stubs(:cookies).returns("new_session_cookie")
    mock_scraper.stubs(:fetch_info).returns("nomeutilizador" => "Test User", "nomeescola" => "Test School")
    mock_scraper.stubs(:extract_guidutente_from_fotoutente).returns(nil)
    GiaeScraperService.stubs(:new).returns(mock_scraper)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(child: @child)
    assert_equal "active", session.status
  end

  test "with_active_session handles failed status" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :failed,
      error_message: "Previous login failed"
    )

    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:login!)
    mock_scraper.stubs(:cookies).returns("new_session_cookie")
    mock_scraper.stubs(:fetch_info).returns("nomeutilizador" => "Test User", "nomeescola" => "Test School")
    mock_scraper.stubs(:extract_guidutente_from_fotoutente).returns(nil)
    GiaeScraperService.stubs(:new).returns(mock_scraper)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(child: @child)
    assert_equal "active", session.status
    assert_nil session.error_message
  end

  test "with_active_session transitions to expired on SessionExpired" do
    # Delete existing sessions to avoid fixture interference
    GiaeSession.where(child: @child).delete_all

    session = GiaeSession.create!(
      child: @child,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "encrypted_cookie"
    )

    # Stub cookie decryption
    GiaeSession.any_instance.stubs(:decrypt_cookie).returns("valid_cookie")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:login!)
    mock_scraper.stubs(:cookies).returns("session_cookie")
    GiaeScraperService.stubs(:new).returns(mock_scraper)

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session do |_|
        raise GiaeScraperService::SessionExpired, "Session expired"
      end
    end

    session.reload
    assert_equal "expired", session.status
  end

  test "with_active_session handles lock wait timeout" do
    # This test is complex because it requires simulating a lock timeout
    # which happens when another transaction holds a lock.
    # For now, we'll skip this test as it's testing database-level locking
    # that is difficult to reproduce in unit tests without actual concurrent transactions.
    skip "Lock timeout testing requires concurrent transactions"
  end

  test "obtain_new_session! transitions to active on success" do
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :pending
    )

    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!)
    mock_scraper.expects(:fetch_info).returns("nomeutilizador" => "Test User", "nomeescola" => "Test School")
    mock_scraper.expects(:extract_guidutente_from_fotoutente).returns(nil)
    mock_scraper.expects(:cookies).returns("new_session_cookie")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    @manager.send(:obtain_new_session!, GiaeSession.find_by(child: @child))

    session = GiaeSession.find_by(child: @child)
    assert_equal "active", session.status
    assert session.refreshed_at.present?
  end

  test "obtain_new_session! transitions to failed on error" do
    GiaeSession.where(child: @child).delete_all

    GiaeSession.create!(
      child: @child,
      status: :pending
    )

    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!).raises(StandardError, "Login failed")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_raises do
      @manager.send(:obtain_new_session!, GiaeSession.find_by(child: @child))
    end

    session = GiaeSession.find_by(child: @child)
    assert_equal "failed", session.status
    assert_match(/Login failed/, session.error_message)
  end

  test "create_fresh_scraper creates scraper with child credentials" do
    # Set up GIAE credentials on the child
    @child.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )

    scraper = @manager.send(:create_fresh_scraper)

    assert_equal @child.giae_username, scraper.instance_variable_get(:@username)
    assert_equal @child.giae_password, scraper.instance_variable_get(:@password)
    assert_equal @child.giae_school_code, scraper.instance_variable_get(:@school_code)
  end

  test "create_scraper_with_session raises error when cookie decryption fails" do
    GiaeSession.where(child: @child).delete_all

    session = GiaeSession.create!(
      child: @child,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "invalid_encrypted_cookie"
    )

    # Mock decrypt to return nil (failed decryption)
    session.expects(:decrypt_cookie).returns(nil)

    error = assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.send(:create_scraper_with_session, session)
    end

    assert_match(/Session invalid/, error.message)

    session.reload
    assert_equal "expired", session.status
  end
end