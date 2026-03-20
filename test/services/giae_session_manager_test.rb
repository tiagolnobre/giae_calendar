# frozen_string_literal: true

require "test_helper"

class GiaeSessionManagerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @manager = GiaeSessionManager.new(@user)
  end

  test "initialize stores user" do
    assert_equal @user, @manager.instance_variable_get(:@user)
  end

  test "LOCK_TIMEOUT constant is set to 30 seconds" do
    assert_equal 30.seconds, GiaeSessionManager::LOCK_TIMEOUT
  end

  test "SessionUnavailable is a StandardError" do
    assert GiaeSessionManager::SessionUnavailable < StandardError
  end

  test "with_active_session raises SessionUnavailable when no session available" do
    # Create a pending session
    GiaeSession.create!(user: @user, status: :pending)

    # Mock the login to fail
    GiaeScraperService.any_instance.expects(:login!).raises(StandardError, "Login failed")

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end
  end

  test "with_active_session raises SessionUnavailable for expired session" do
    # Create an expired session
    GiaeSession.create!(
      user: @user,
      status: :expired,
      refreshed_at: 25.hours.ago
    )

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end
  end

  test "with_active_session handles session age check" do
    # Create an old active session
    GiaeSession.create!(
      user: @user,
      status: :active,
      refreshed_at: 25.hours.ago,
      session_cookie_ciphertext: "test"
    )

    error = assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end

    assert_match(/Session expired due to age/, error.message)
  end

  test "with_active_session uses valid active session" do
    session = GiaeSession.create!(
      user: @user,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "encrypted_cookie"
    )

    mock_scraper = mock("scraper")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    # Mock decrypt_cookie
    session.expects(:decrypt_cookie).returns("decrypted_cookie")

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
    GiaeSession.create!(
      user: @user,
      status: :refreshing,
      locked_at: 1.minute.ago,
      locked_by: "other-job-123"
    )

    error = assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end

    assert_match(/Session locked by another process/, error.message)
  end

  test "with_active_session takes over stale lock" do
    GiaeSession.create!(
      user: @user,
      status: :refreshing,
      locked_at: 2.minutes.ago,
      locked_by: "old-job-456"
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!)
    mock_scraper.expects(:cookies).returns("new_session_cookie")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(user: @user)
    assert_equal "active", session.status
  end

  test "with_active_session handles pending status" do
    GiaeSession.create!(
      user: @user,
      status: :pending
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!)
    mock_scraper.expects(:cookies).returns("new_session_cookie")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    mock_scraper_with_session = mock("scraper_with_session")
    GiaeScraperService.expects(:new).returns(mock_scraper_with_session)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(user: @user)
    assert_equal "active", session.status
  end

  test "with_active_session handles failed status" do
    GiaeSession.create!(
      user: @user,
      status: :failed,
      error_message: "Previous login failed"
    )

    # Mock successful login
    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!)
    mock_scraper.expects(:cookies).returns("new_session_cookie")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    mock_scraper_with_session = mock("scraper_with_session")
    GiaeScraperService.expects(:new).returns(mock_scraper_with_session)

    @manager.with_active_session { |_| }

    session = GiaeSession.find_by(user: @user)
    assert_equal "active", session.status
    assert_nil session.error_message
  end

  test "with_active_session transitions to expired on SessionExpired" do
    session = GiaeSession.create!(
      user: @user,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "encrypted_cookie"
    )

    mock_scraper = mock("scraper")
    GiaeScraperService.expects(:new).returns(mock_scraper)
    session.expects(:decrypt_cookie).returns("decrypted_cookie")

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session do |_|
        raise GiaeScraperService::SessionExpired, "Session expired"
      end
    end

    session.reload
    assert_equal "expired", session.status
  end

  test "with_active_session handles lock wait timeout" do
    # Create a session that will cause lock timeout
    GiaeSession.create!(
      user: @user,
      status: :active,
      refreshed_at: 1.hour.ago,
      session_cookie_ciphertext: "encrypted_cookie"
    )

    # Simulate lock timeout
    ActiveRecord::Base.connection.expects(:execute).raises(ActiveRecord::LockWaitTimeout)

    error = assert_raises(GiaeSessionManager::SessionUnavailable) do
      @manager.with_active_session { |_| }
    end

    assert_match(/Could not acquire session lock/, error.message)
  end

  test "obtain_new_session! transitions to active on success" do
    GiaeSession.create!(
      user: @user,
      status: :pending
    )

    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!)
    mock_scraper.expects(:cookies).returns("new_session_cookie")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    @manager.send(:obtain_new_session!, GiaeSession.find_by(user: @user))

    session = GiaeSession.find_by(user: @user)
    assert_equal "active", session.status
    assert session.refreshed_at.present?
  end

  test "obtain_new_session! transitions to failed on error" do
    GiaeSession.create!(
      user: @user,
      status: :pending
    )

    mock_scraper = mock("scraper")
    mock_scraper.expects(:login!).raises(StandardError, "Login failed")
    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_raises do
      @manager.send(:obtain_new_session!, GiaeSession.find_by(user: @user))
    end

    session = GiaeSession.find_by(user: @user)
    assert_equal "failed", session.status
    assert_match(/Login failed/, session.error_message)
  end

  test "create_fresh_scraper creates scraper with user credentials" do
    scraper = @manager.send(:create_fresh_scraper)

    assert_equal @user.giae_username, scraper.instance_variable_get(:@username)
    assert_equal @user.giae_password, scraper.instance_variable_get(:@password)
    assert_equal @user.giae_school_code, scraper.instance_variable_get(:@school_code)
  end

  test "create_scraper_with_session raises error when cookie decryption fails" do
    session = GiaeSession.create!(
      user: @user,
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
