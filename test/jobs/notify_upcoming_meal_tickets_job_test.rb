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

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 1, final_count - initial_count

    notification = Notification.where(user: user).last
    assert notification.body.include?(@tomorrow.strftime("%d de %B"))
  end

  test "should not notify user with ticket for tomorrow but no meal detail" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true)
    user.meal_tickets.create!(date: @tomorrow, bought: true)

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 0, final_count - initial_count
  end

  test "should notify user with ticket and meal detail for tomorrow" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true, email_notifications_enabled: false)
    user.meal_tickets.create!(date: @tomorrow, bought: true)
    user.meal_details.create!(date: @tomorrow, period: "Almoço", main_dish: "Arroz de pato")

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 1, final_count - initial_count

    notification = Notification.where(user: user).last
    assert notification.body.include?("Arroz de pato")
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

  test "should include tomorrow's date in no-ticket notification" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true)

    NotifyUpcomingMealTicketsJob.perform_now

    notification = Notification.where(user: user).last
    assert notification.title.include?("amanhã") || notification.title.include?("Tomorrow")
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

  test "should continue processing other users when one fails" do
    user_one = users(:one)
    user_two = users(:two)

    user_one.update!(in_app_notifications_enabled: true, email_notifications_enabled: false)
    user_two.update!(in_app_notifications_enabled: true, email_notifications_enabled: false)

    MealTicket.stubs(:exists?).raises(ActiveRecord::ConnectionTimeoutError.new("timeout")).then.returns(false)

    initial_count_two = Notification.where(user: user_two).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count_two = Notification.where(user: user_two).count
    assert final_count_two > initial_count_two,
      "user_two should still receive a notification even when user_one fails"
  end

  test "should not send menu notification when meal detail has no main_dish" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true)
    user.meal_tickets.create!(date: @tomorrow, bought: true)
    user.meal_details.create!(date: @tomorrow, period: "Almoço", main_dish: nil)

    initial_count = Notification.where(user: user).count

    NotifyUpcomingMealTicketsJob.perform_now

    final_count = Notification.where(user: user).count
    assert_equal 0, final_count - initial_count
  end

  test "should send menu notification instead of no-ticket when user has ticket" do
    user = users(:one)
    user.update!(in_app_notifications_enabled: true, email_notifications_enabled: false)
    user.meal_tickets.create!(date: @tomorrow, bought: true)
    user.meal_details.create!(date: @tomorrow, period: "Almoço", main_dish: "Bacalhau à Brás")

    NotifyUpcomingMealTicketsJob.perform_now

    notification = Notification.where(user: user).last
    assert notification.title.include?("Menu") || notification.title.include?("menu")
    assert notification.body.include?("Bacalhau à Brás")
  end
end
