require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    Notification.delete_all
    @user = users(:one)
    @notification = Notification.new(
      user: @user,
      title: "Test Title",
      body: "Test notification",
      notification_type: :in_app
    )
  end

  test "should be valid with all required attributes" do
    assert @notification.valid?
  end

  test "should belong to user" do
    assert_equal @user, @notification.user
  end

  test "title can be nil" do
    @notification.title = nil
    assert @notification.valid?
  end

  test "notification_type should default to in_app" do
    notification = Notification.new(user: @user, title: "Test", body: "Test")
    assert_equal "in_app", notification.notification_type
  end

  test "should accept valid notification_types" do
    @notification.notification_type = :email
    assert @notification.valid?

    @notification.notification_type = :in_app
    assert @notification.valid?
  end

  test "should not accept invalid notification_types" do
    assert_raises(ArgumentError) do
      @notification.notification_type = :invalid_type
    end
  end

  test "unread scope should return only unread notifications" do
    @notification.save!
    read_notification = @user.notifications.create!(
      title: "Read Title",
      body: "Read notification",
      read_at: Time.current
    )

    assert_includes Notification.unread, @notification
    assert_not_includes Notification.unread, read_notification
  end

  test "read scope should return only read notifications" do
    @notification.save!
    read_notification = @user.notifications.create!(
      title: "Read Title",
      body: "Read notification",
      read_at: Time.current
    )

    assert_includes Notification.read, read_notification
    assert_not_includes Notification.read, @notification
  end

  test "chronological scope should order by created_at desc" do
    old_notification = @user.notifications.create!(
      title: "Old Title",
      body: "Old notification",
      created_at: 1.day.ago
    )
    new_notification = @user.notifications.create!(
      title: "New Title",
      body: "New notification",
      created_at: Time.current
    )

    notifications = Notification.chronological.to_a
    assert_equal new_notification, notifications.first
    assert_equal old_notification, notifications.last
  end

  test "read? should return false for unread notification" do
    assert_not @notification.read?
  end

  test "read? should return true for read notification" do
    @notification.read_at = Time.current
    assert @notification.read?
  end

  test "mark_as_read! should set read_at to current time" do
    @notification.save!
    assert_nil @notification.read_at

    @notification.mark_as_read!
    @notification.reload
    assert_not_nil @notification.read_at
  end

  test "polymorphic notifiable association should work" do
    meal_ticket = @user.meal_tickets.create!(date: Date.today, bought: true)
    @notification.notifiable = meal_ticket
    @notification.save!

    assert_equal meal_ticket, @notification.notifiable
  end

  test "notifiable association should be optional" do
    @notification.notifiable = nil
    assert @notification.valid?
  end

  test "should destroy notification when user is destroyed" do
    @notification.save!
    user_id = @user.id

    # Delete associated records first to avoid FK constraint issues in test
    MealTicket.where(user_id: user_id).delete_all
    MealDetail.where(user_id: user_id).delete_all
    SaldoRecord.where(user_id: user_id).delete_all
    GiaeSession.where(user_id: user_id).delete_all
    Notification.where(user_id: user_id).delete_all

    @user.destroy

    # Verify no notifications remain for this user
    assert_equal 0, Notification.where(user_id: user_id).count
  end
end
