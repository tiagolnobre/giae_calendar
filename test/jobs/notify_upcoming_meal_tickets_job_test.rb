require "test_helper"

class NotifyUpcomingMealTicketsJobTest < ActiveJob::TestCase
  setup do
    @tomorrow = Date.tomorrow
  end

  test "should notify user without ticket for tomorrow" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: true,
      email_notifications_enabled: false
    )

    # Clear any existing notifications from fixtures
    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 1, final_count - initial_count

    notification = Notification.where(user: user).last
    assert notification.body.include?(@tomorrow.strftime("%d de %B"))
  end

  test "should not notify user with ticket for tomorrow" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true)
    user.meal_tickets.create!(date: @tomorrow, bought: true)

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 0, final_count - initial_count
  end

  test "should not notify user when notifications disabled" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: false,
      email_notifications_enabled: false
    )

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 0, final_count - initial_count
  end

  test "should send in-app notification when enabled" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: true,
      email_notifications_enabled: false
    )

    NotifyUpcomingMealTicketsJob.perform_now

    notification = Notification.where(user: user).last
    assert_equal "in_app", notification.notification_type
  end

  test "should send email notification when enabled" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: false,
      email_notifications_enabled: true
    )

    NotifyUpcomingMealTicketsJob.perform_now

    notification = Notification.where(user: user).last
    assert_equal "email", notification.notification_type
  end

  test "should send both notifications when both enabled" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: true,
      email_notifications_enabled: true
    )

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 2, final_count - initial_count

    types = user.reload.notifications.pluck(:notification_type)
    assert_includes types, "in_app"
    assert_includes types, "email"
  end

  test "should include tomorrow's date in notification" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true)

    NotifyUpcomingMealTicketsJob.perform_now

    notification = Notification.where(user: user).last
    assert notification.title.include?("amanhã")
    assert notification.body.include?(@tomorrow.strftime("%d de %B"))
  end

  test "should handle users with only email notifications" do
    user = users(:one)
    user.update!(
      in_app_notifications_enabled: false,
      email_notifications_enabled: true
    )

    initial_jobs_count = enqueued_jobs.count

    NotifyUpcomingMealTicketsJob.perform_now

    assert enqueued_jobs.count > initial_jobs_count
  end
end
