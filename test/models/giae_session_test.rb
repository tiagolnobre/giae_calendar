# frozen_string_literal: true

require "test_helper"

class GiaeSessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "should create session with pending status by default" do
    session = GiaeSession.create!(user: @user)
    assert_equal "pending", session.status
  end

  test "should transition to active with encrypted cookie" do
    session = GiaeSession.create!(user: @user)
    session.transition_to_active!("test_cookie=value123")

    assert_equal "active", session.status
    assert_not_nil session.session_cookie_ciphertext
    assert_not_nil session.obtained_at
    assert_not_nil session.refreshed_at
    assert_not_nil session.last_used_at
    assert_nil session.lock_key
    assert_nil session.error_message
  end

  test "should decrypt cookie correctly" do
    session = GiaeSession.create!(user: @user)
    session.transition_to_active!("test_cookie=value123")

    decrypted = session.decrypt_cookie
    assert_equal "test_cookie=value123", decrypted
  end

  test "should handle invalid cookie gracefully" do
    session = GiaeSession.create!(user: @user, session_cookie_ciphertext: "invalid")
    decrypted = session.decrypt_cookie
    assert_nil decrypted
  end

  test "should transition to refreshing with lock" do
    session = GiaeSession.create!(user: @user, status: :active, obtained_at: Time.current)
    session.transition_to_refreshing!(locked_by: "TestJob-123")

    assert_equal "refreshing", session.status
    assert_not_nil session.lock_key
    assert_not_nil session.locked_at
    assert_equal "TestJob-123", session.locked_by
    assert_nil session.last_used_at
  end

  test "should transition to expired and clear cookie" do
    session = GiaeSession.create!(user: @user, status: :active)
    session.transition_to_active!("test_cookie")
    session.transition_to_expired!

    assert_equal "expired", session.status
    assert_nil session.session_cookie_ciphertext
    assert_nil session.lock_key
    assert_nil session.expires_at
    # Should keep obtained_at for audit
    assert_not_nil session.obtained_at
  end

  test "should transition to failed with error message" do
    session = GiaeSession.create!(user: @user, status: :refreshing, refreshed_at: Time.current)
    session.transition_to_failed!("Login failed: invalid credentials")

    assert_equal "failed", session.status
    assert_equal "Login failed: invalid credentials", session.error_message
    assert_nil session.lock_key
    assert_nil session.session_cookie_ciphertext
    assert_nil session.obtained_at
    # Should keep refreshed_at
    assert_not_nil session.refreshed_at
  end

  test "should transition to pending and clear all data" do
    session = GiaeSession.create!(user: @user, status: :failed, error_message: "Error")
    session.transition_to_pending!

    assert_equal "pending", session.status
    assert_nil session.session_cookie_ciphertext
    assert_nil session.error_message
    assert_nil session.lock_key
    assert_nil session.locked_at
    assert_nil session.obtained_at
    assert_nil session.refreshed_at
    assert_nil session.last_used_at
  end

  test "should validate user presence" do
    session = GiaeSession.new
    assert_not session.valid?
    assert_includes session.errors[:user_id], "can't be blank"
  end

  test "should validate status inclusion" do
    # Test that invalid status raises an ArgumentError from enum
    assert_raises(ArgumentError) do
      GiaeSession.new(user: @user, status: "invalid_status")
    end
  end
end
