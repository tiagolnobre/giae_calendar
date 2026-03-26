require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "should belong to user" do
    subscription = PushSubscription.new(user: @user, endpoint: "https://example.com", p256dh: "test", auth: "test")
    assert_equal @user, subscription.user
  end

  test "should require endpoint" do
    subscription = PushSubscription.new(user: @user, p256dh: "test", auth: "test")
    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
  end

  test "should require p256dh" do
    subscription = PushSubscription.new(user: @user, endpoint: "https://example.com", auth: "test")
    assert_not subscription.valid?
    assert_includes subscription.errors[:p256dh], "can't be blank"
  end

  test "should require auth" do
    subscription = PushSubscription.new(user: @user, endpoint: "https://example.com", p256dh: "test")
    assert_not subscription.valid?
    assert_includes subscription.errors[:auth], "can't be blank"
  end

  test "should have unique endpoint per user" do
    PushSubscription.create!(user: @user, endpoint: "https://example.com", p256dh: "test", auth: "test")
    duplicate = PushSubscription.new(user: @user, endpoint: "https://example.com", p256dh: "test2", auth: "test2")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:endpoint], "has already been taken"
  end

  test "should allow same endpoint for different users" do
    other_user = users(:two)
    PushSubscription.create!(user: @user, endpoint: "https://example.com", p256dh: "test", auth: "test")
    other_subscription = PushSubscription.new(user: other_user, endpoint: "https://example.com", p256dh: "test", auth: "test")
    assert other_subscription.valid?
  end
end
