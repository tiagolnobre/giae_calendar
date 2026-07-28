require "test_helper"

class ChildTest < ActiveJob::TestCase
  setup do
    @child = children(:one)
    @child.update!(giae_username: "testuser", giae_password: "testpass")
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "should belong to user" do
    assert_instance_of User, @child.user
  end

  test "should encrypt GIAE credentials" do
    assert_equal "testuser", @child.giae_username
    raw = ActiveRecord::Base.connection.execute(
      "SELECT giae_username FROM children WHERE id = #{@child.id}"
    ).first["giae_username"]
    assert_match /^{"p":/, raw
    assert_not_equal "testuser", raw
  end

  test "should have default school code" do
    child = users(:one).children.build(giae_username: "newuser", giae_password: "newpass")
    child.valid?
    assert_equal "161676", child.giae_school_code
  end

  test "should not be valid without giae_username" do
    child = Child.new
    assert_not child.valid?
    assert_includes child.errors[:giae_username], "can't be blank"
  end

  test "refresh_in_progress? checks cache keys" do
    assert_not @child.refresh_in_progress?
    Rails.cache.write("refresh_meal_tickets_#{@child.id}", true)
    assert @child.refresh_in_progress?
  end
end
