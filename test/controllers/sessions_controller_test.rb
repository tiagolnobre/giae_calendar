require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get new" do
    get sign_in_path
    assert_response :success
  end

  test "should redirect to calendar when already signed in" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
    get sign_in_path
    assert_redirected_to %r{/calendar}
  end

  test "should create session with valid credentials" do
    post sign_in_path, params: {
      email: @user.email,
      password: "password123"
    }

    assert_redirected_to %r{/calendar}
  end

  test "should not create session with invalid email" do
    post sign_in_path, params: {
      email: "nonexistent@example.com",
      password: "password123"
    }

    assert_response :unprocessable_entity
  end

  test "should not create session with invalid password" do
    post sign_in_path, params: {
      email: @user.email,
      password: "wrongpassword"
    }

    assert_response :unprocessable_entity
  end

  test "should destroy session" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
    delete sign_out_path
    assert_redirected_to %r{/sign_in}
  end

  test "should require authentication for protected pages after sign out" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
    delete sign_out_path
    get calendar_path
    assert_redirected_to %r{/sign_in}
  end
end
