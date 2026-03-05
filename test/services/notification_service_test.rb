require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @service = NotificationService.new(@user)
  end

  test "should create in-app notification when type is in_app" do
    @user.update!(in_app_notifications_enabled: true)

    assert_difference "Notification.count", 1 do
      @service.notify("Test Title", "Test Body", types: [ :in_app ])
    end

    notification = Notification.last
    assert_equal "Test Title", notification.title
    assert_equal "Test Body", notification.body
    assert_equal "in_app", notification.notification_type
  end

  test "should create email notification when type is email" do
    @user.update!(email_notifications_enabled: true)

    assert_difference "Notification.count", 1 do
      @service.notify("Test Title", "Test Body", types: [ :email ])
    end

    notification = Notification.last
    assert_equal "email", notification.notification_type
  end

  test "should not create notification when in-app disabled" do
    @user.update!(in_app_notifications_enabled: false)

    assert_no_difference "Notification.count" do
      @service.notify("Test Title", "Test Body", types: [ :in_app ])
    end
  end

  test "should not create notification when email disabled" do
    @user.update!(email_notifications_enabled: false)

    assert_no_difference "Notification.count" do
      @service.notify("Test Title", "Test Body", types: [ :email ])
    end
  end

  test "should create both notifications when both types provided" do
    @user.update!(
      in_app_notifications_enabled: true,
      email_notifications_enabled: true
    )

    assert_difference "Notification.count", 2 do
      @service.notify("Test Title", "Test Body", types: [ :in_app, :email ])
    end
  end

  test "should default to in_app when types not specified" do
    @user.update!(in_app_notifications_enabled: true)

    assert_difference "Notification.count", 1 do
      @service.notify("Test Title", "Test Body")
    end

    notification = Notification.last
    assert_equal "in_app", notification.notification_type
  end

  test "should associate notification with notifiable" do
    @user.update!(in_app_notifications_enabled: true)
    meal_ticket = @user.meal_tickets.create!(date: Date.today, bought: true)

    @service.notify("Test Title", "Test Body", notifiable: meal_ticket, types: [ :in_app ])

    notification = Notification.last
    assert_equal meal_ticket, notification.notifiable
  end

  test "should handle nil notifiable" do
    @user.update!(in_app_notifications_enabled: true)

    assert_difference "Notification.count", 1 do
      @service.notify("Test Title", "Test Body", notifiable: nil, types: [ :in_app ])
    end

    notification = Notification.last
    assert_nil notification.notifiable
  end

  test "should handle empty types array" do
    @user.update!(in_app_notifications_enabled: true)

    assert_no_difference "Notification.count" do
      @service.notify("Test Title", "Test Body", types: [])
    end
  end

  test "should create notification record for email type" do
    @user.update!(email_notifications_enabled: true)

    assert_difference "Notification.count", 1 do
      @service.notify("Email Title", "Email Body", types: [ :email ])
    end

    notification = Notification.last
    assert_equal "Email Title", notification.title
    assert_equal "email", notification.notification_type
  end
end
