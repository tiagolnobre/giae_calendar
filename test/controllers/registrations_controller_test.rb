require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get sign_up_path
    assert_response :success
  end

  test "should create user and child" do
    assert_difference("User.count", 1) do
      assert_difference("Child.count", 1) do
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
    end

    assert_redirected_to %r{/calendar}
    assert_equal I18n.t("flash.account_created"), flash[:notice]

    child = User.last.children.first
    assert_equal "newgiaeuser", child.giae_username
    assert_equal "newgiaepass", child.giae_password
  end

  test "should not create user with invalid data" do
    assert_no_difference("User.count") do
      assert_no_difference("Child.count") do
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
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with password mismatch" do
    assert_no_difference("User.count") do
      assert_no_difference("Child.count") do
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
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    User.create!(
      email: "existing@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_no_difference("User.count") do
      assert_no_difference("Child.count") do
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
    end

    assert_response :unprocessable_entity
  end

  test "should not create user without GIAE credentials" do
    assert_no_difference("User.count") do
      assert_no_difference("Child.count") do
        post sign_up_path, params: {
          user: {
            email: "nocreds@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "should get edit when authenticated" do
    user = User.create!(
      email: "edituser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_redirected_to %r{/calendar}
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
      password_confirmation: "password123"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_redirected_to %r{/calendar}
    patch account_path, params: {
      user: {
        email: "updated@example.com"
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
      password_confirmation: "password123"
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_redirected_to %r{/calendar}
    patch account_path, params: {
      user: {
        email: ""
      }
    }

    assert_response :unprocessable_entity
  end
end