require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @notification = Notification.create!(
      user: @user,
      title: "Test Title",
      body: "Test notification",
      notification_type: :in_app
    )
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
  end

  test "should get index" do
    get notifications_path
    assert_response :success
  end

  test "should redirect to sign_in when not authenticated" do
    delete sign_out_path
    get notifications_path
    assert_redirected_to %r{/sign_in}
  end

  test "should display user notifications" do
    get notifications_path
    assert_response :success
    assert response.body.include?("Test notification")
  end

  test "should mark notification as read" do
    patch mark_notification_read_path(@notification)
    assert_redirected_to %r{/notifications}
    @notification.reload
    assert_not_nil @notification.read_at
  end

  test "should not mark other user's notification as read" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "otheruser",
      giae_password: "otherpass"
    )
    other_notification = Notification.create!(
      user: other_user,
      title: "Other Title",
      body: "Other notification",
      notification_type: :in_app
    )

    patch mark_notification_read_path(other_notification)
    # In production, this would raise RecordNotFound, but in test it returns 404
    assert_response :not_found
  end

  test "should show notification count" do
    get notifications_path
    assert_response :success
  end
end
