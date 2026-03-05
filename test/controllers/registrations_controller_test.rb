require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get sign_up_path
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          giae_username: "newgiaeuser",
          giae_password: "newgiaepass"
        }
      }
    end

    assert_redirected_to %r{/calendar}
  end

  test "should not create user with invalid data" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "",
          password: "password123",
          password_confirmation: "password123",
          giae_username: "newuser",
          giae_password: "pass"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with password mismatch" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "different",
          giae_username: "newuser",
          giae_password: "pass"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    User.create!(
      email: "existing@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "existinguser",
      giae_password: "existingpass"
    )

    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "existing@example.com",
          password: "password123",
          password_confirmation: "password123",
          giae_username: "newuser",
          giae_password: "pass"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit when authenticated" do
    user = User.create!(
      email: "edituser@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "edituser",
      giae_password: "editpass"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    follow_redirect!
    get edit_account_path
    assert_response :success
  end

  test "should redirect edit when not authenticated" do
    get edit_account_path
    assert_redirected_to %r{/sign_in}
  end

  test "should update user when authenticated" do
    user = User.create!(
      email: "updateuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "updateuser",
      giae_password: "updatepass"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    follow_redirect!
    patch account_path, params: {
      user: {
        email: "updated@example.com",
        giae_username: "updateduser"
      }
    }

    assert_redirected_to %r{/calendar}
    user.reload
    assert_equal "updated@example.com", user.email
  end

  test "should not update user with invalid data" do
    user = User.create!(
      email: "invaliduser@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "invaliduser",
      giae_password: "invalidpass"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    follow_redirect!
    patch account_path, params: {
      user: {
        email: ""
      }
    }

    assert_response :unprocessable_entity
  end
end
