# frozen_string_literal: true

require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "user_session returns user id from session" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert_equal @user.id, session[:user_id]
  end

  test "user_session returns nil when not signed in" do
    get calendar_path
    assert_nil session[:user_id]
  end

  test "current_user returns user from session" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert_equal @user.id, controller.current_user.id
  end

  test "current_user returns user from remember cookie" do
    # Create remember token
    token = @user.remember_me!

    # Set cookie
    cookies.signed[:remember_token] = token

    get calendar_path
    assert_equal @user.id, controller.current_user.id
    assert_equal @user.id, session[:user_id]  # Should restore session
  end

  test "current_user returns nil with invalid remember cookie" do
    cookies.signed[:remember_token] = "invalid_token"

    get calendar_path
    assert_nil controller.current_user
  end

  test "current_user returns nil when user deleted" do
    # Create remember token
    token = @user.remember_me!
    cookies.signed[:remember_token] = token

    # Delete user
    @user.destroy

    get calendar_path
    assert_nil controller.current_user
  end

  test "current_user handles expired remember token" do
    token = @user.remember_me!
    cookies.signed[:remember_token] = token

    # Expire the token
    @user.update!(remember_token_expires_at: 1.day.ago)

    get calendar_path
    assert_nil controller.current_user
  end

  test "current_user caches result" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    first_call = controller.current_user
    second_call = controller.current_user
    assert_equal first_call.object_id, second_call.object_id
  end

  test "user_signed_in? returns true when authenticated" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert controller.user_signed_in?
  end

  test "user_signed_in? returns false when not authenticated" do
    get calendar_path
    assert_not controller.user_signed_in?
  end

  test "authenticate_user! redirects when not signed in" do
    get calendar_path
    assert_redirected_to sign_in_path
    assert_equal "Please sign in to continue.", flash[:alert]
  end

  test "authenticate_user! allows access when signed in" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert_response :success
  end

  test "sign_in sets user_id in session" do
    post sign_in_path, params: { email: @user.email, password: "password123" }

    assert_equal @user.id, session[:user_id]
  end

  test "sign_out clears session" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    delete sign_out_path
    follow_redirect!

    assert_nil session[:user_id]
  end

  test "sign_out clears remember cookie" do
    # Sign in with remember me
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }

    assert cookies[:remember_token].present?

    delete sign_out_path
    follow_redirect!

    assert cookies[:remember_token].blank?
  end

  test "sign_out clears user remember token" do
    token = @user.remember_me!
    cookies.signed[:remember_token] = token

    delete sign_out_path
    follow_redirect!

    @user.reload
    assert_nil @user.remember_token
    assert_nil @user.remember_token_expires_at
  end

  test "remember_user creates remember cookie" do
    post sign_in_path, params: {
      email: @user.email,
      password: "password123",
      remember_me: "1"
    }

    assert cookies[:remember_token].present?
    assert_equal User::REMEMBER_EXPIRATION, cookies[:remember_token].expires
    assert cookies[:remember_token].http_only?
  end

  test "remember_user sets secure flag in production" do
    # Mock production environment
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      post sign_in_path, params: {
        email: @user.email,
        password: "password123",
        remember_me: "1"
      }

      assert cookies[:remember_token].present?
    end
  end

  test "user_from_remember_cookie restores session" do
    token = @user.remember_me!
    cookies.signed[:remember_token] = token

    get calendar_path

    # Should restore session from cookie
    assert_equal @user.id, session[:user_id]
  end

  test "user_from_remember_cookie handles missing cookie" do
    get calendar_path

    assert_nil controller.current_user
    assert_nil session[:user_id]
  end

  test "user_from_remember_cookie handles blank cookie" do
    cookies.signed[:remember_token] = ""

    get calendar_path
    assert_nil controller.current_user
  end

  test "user_from_remember_cookie handles invalid cookie signature" do
    # Set invalid cookie (won't match signed format)
    cookies[:remember_token] = "tampered"

    get calendar_path
    assert_nil controller.current_user
  end
end
