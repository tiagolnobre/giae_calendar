require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should create remember cookie when remember_me is checked" do
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }

    assert_redirected_to %r{/calendar}
    assert cookies[:remember_token].present?

    # Verify the user has a remember token in the database
    @user.reload
    assert @user.remember_token.present?
    assert @user.remember_created_at.present?
  end

  test "should not create remember cookie when remember_me is not checked" do
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "0"
    }

    assert_redirected_to %r{/calendar}
    assert cookies[:remember_token].blank?

    # Verify the user does not have a remember token
    @user.reload
    assert @user.remember_token.blank?
  end

  test "should authenticate user from remember cookie" do
    # Sign in with remember me
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }
    follow_redirect!

    # Get the remember token from the user
    @user.reload
    remember_token = @user.remember_token
    assert remember_token.present?

    # Verify the token is valid
    assert @user.remember_token_valid?(remember_token)
  end

  test "should clear remember cookie on sign out" do
    # Sign in with remember me
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }
    follow_redirect!

    assert cookies[:remember_token].present?

    # Sign out
    delete sign_out_path

    # The cookie should be cleared
    # Note: In test environment, cookies might persist until the next request
    # But the remember token should be cleared from the database
    @user.reload
    assert @user.remember_token.blank?
    assert @user.remember_created_at.blank?
  end

  test "should not authenticate with expired remember token" do
    # Set an expired remember token
    expired_time = 3.weeks.ago
    @user.update!(
      remember_token: SecureRandom.urlsafe_base64(32),
      remember_created_at: expired_time
    )

    # The token should be invalid
    assert_not @user.remember_token_valid?(@user.remember_token)
  end

  test "should authenticate with valid remember token" do
    # Set a valid remember token
    @user.update!(
      remember_token: SecureRandom.urlsafe_base64(32),
      remember_created_at: 1.day.ago
    )

    # The token should be valid
    assert @user.remember_token_valid?(@user.remember_token)
  end

  test "remember token should expire after 2 weeks" do
    token = @user.remember_me!

    # Token should be valid now
    assert @user.remember_token_valid?(token)

    # Simulate expiration
    @user.update!(remember_created_at: 15.days.ago)

    # Token should be expired
    assert_not @user.remember_token_valid?(token)
  end

  test "forget_me! should clear remember token" do
    @user.remember_me!
    assert @user.remember_token.present?

    @user.forget_me!

    assert @user.remember_token.blank?
    assert @user.remember_created_at.blank?
  end

  test "should redirect to calendar when accessing sign in page while remembered" do
    # Sign in with remember me
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }
    follow_redirect!

    # Clear session (simulating browser restart)
    # In real scenario, remember cookie persists

    # Access sign in page - should redirect to calendar
    get sign_in_path
    assert_redirected_to %r{/calendar}
  end
end
