require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "testuser",
      giae_password: "testpass"
    )
  end

  test "should get sign in page" do
    get sign_in_path
    assert_response :success
    assert_select "h1", I18n.t("app_name")
  end

  test "should get sign up page" do
    get sign_up_path
    assert_response :success
    assert_select "h1", I18n.t("app_name")
  end

  test "should sign in with valid credentials" do
    post sign_in_path, params: {
      email: "test@example.com",
      password: "password123"
    }
    assert_redirected_to %r{/calendar}
    follow_redirect!
    assert_select "h1", I18n.t("calendar.meals")
  end

  test "should not sign in with invalid email" do
    post sign_in_path, params: {
      email: "wrong@example.com",
      password: "password123"
    }
    assert_response :unprocessable_entity
  end

  test "should not sign in with invalid password" do
    post sign_in_path, params: {
      email: "test@example.com",
      password: "wrongpassword"
    }
    assert_response :unprocessable_entity
  end

  test "should sign up with valid attributes" do
    assert_difference "User.count", 1 do
      post sign_up_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123",
          giae_username: "newuser",
          giae_password: "newpass"
        }
      }
    end
    assert_redirected_to %r{/calendar}
  end

  test "should not sign up with duplicate email" do
    post sign_up_path, params: {
      user: {
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        giae_username: "user",
        giae_password: "pass"
      }
    }
    assert_response :unprocessable_entity
  end

  test "should sign out" do
    post sign_in_path, params: {
      email: "test@example.com",
      password: "password123"
    }
    delete sign_out_path
    assert_redirected_to %r{/sign_in}
  end

  test "should require authentication for calendar" do
    get calendar_path
    assert_redirected_to %r{/sign_in}
  end
end
