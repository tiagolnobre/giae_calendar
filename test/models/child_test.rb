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

  test "defaults school code when blank on creation" do
    child = users(:one).children.create!(
      giae_username: "newuser",
      giae_password: "newpass",
      giae_school_code: ""
    )
    assert_equal "161676", child.reload.giae_school_code
  end

  test "defaults school code when blank on update" do
    @child.update!(giae_school_code: "")
    assert_equal "161676", @child.reload.giae_school_code
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
    Rails.cache.delete("refresh_meal_tickets_#{@child.id}")

    Rails.cache.write("fetch_saldo_#{@child.id}", true)
    assert @child.refresh_in_progress?
  end

  test "refresh_in_progress? returns false when no refresh is running" do
    assert_not @child.refresh_in_progress?
  end

  test "display_name returns nome_utilizador when present" do
    @child.update!(nome_utilizador: "Maria Nobre")
    assert_equal "Maria Nobre", @child.display_name
  end

  test "display_name falls back to giae_username" do
    @child.update!(nome_utilizador: nil)
    assert_equal "testuser", @child.display_name
  end

  test "display_name falls back to id label" do
    @child.update_columns(nome_utilizador: nil, giae_username: nil)
    assert_equal "Child ##{@child.id}", @child.display_name
  end

  test "latest_saldo returns most recent saldo record" do
    @child.saldo_records.create!(cents: 1000, user: @child.user)
    @child.saldo_records.create!(cents: 2500, user: @child.user)

    assert_equal 2500, @child.latest_saldo.cents
  end

  test "latest_saldo returns nil when no records" do
    assert_nil @child.latest_saldo
  end

  test "meal_tickets_for_month returns tickets for specified month ordered by date" do
    @child.meal_tickets.create!(date: Date.new(2024, 1, 15), bought: true)
    @child.meal_tickets.create!(date: Date.new(2024, 1, 10), bought: true)
    @child.meal_tickets.create!(date: Date.new(2024, 2, 10), bought: true)

    tickets = @child.meal_tickets_for_month(1, 2024).to_a

    assert_equal [ Date.new(2024, 1, 10), Date.new(2024, 1, 15) ], tickets.map(&:date)
  end

  test "current_month_tickets returns tickets for current month" do
    today = Date.today

    today_ticket = @child.meal_tickets.create!(date: today, bought: true)
    prev_ticket = @child.meal_tickets.create!(date: today.prev_month, bought: true)

    current_tickets = @child.current_month_tickets

    assert_includes current_tickets, today_ticket
    assert_not_includes current_tickets, prev_ticket
  end

  test "has_many meal_tickets association" do
    ticket = @child.meal_tickets.create!(date: Date.today, bought: true)
    assert_equal @child, ticket.child
    assert_includes @child.meal_tickets, ticket
  end

  test "has_many meal_details association" do
    detail = @child.meal_details.create!(date: Date.today, period: "Lunch", soup: "Soup")
    assert_equal @child, detail.child
    assert_includes @child.meal_details, detail
  end

  test "has_many saldo_records association" do
    record = @child.saldo_records.create!(cents: 1000, user: @child.user)
    assert_equal @child, record.child
    assert_includes @child.saldo_records, record
  end

  test "has_many school_years association" do
    school_year = @child.school_years.create!(label: "2025/2026", user: @child.user)
    assert_equal @child, school_year.child
    assert_includes @child.school_years, school_year
  end

  test "has_many notifications association" do
    notification = @child.notifications.create!(user: @child.user, title: "Test", body: "Body")
    assert_equal @child, notification.child
    assert_includes @child.notifications, notification
  end

  test "has_one giae_session association" do
    new_child = @child.user.children.create!(giae_username: "freshuser", giae_password: "freshpass")
    session = GiaeSession.create!(child: new_child, user: @child.user, status: :pending)

    assert_equal new_child, session.child
    assert_equal session, new_child.giae_session
  end

  test "destroy cascades to child-scoped records" do
    new_child = @child.user.children.create!(giae_username: "freshuser", giae_password: "freshpass")
    new_child.meal_tickets.create!(date: Date.today, bought: true)
    new_child.meal_details.create!(date: Date.today, period: "Lunch", soup: "Soup")
    new_child.saldo_records.create!(cents: 1000, user: @child.user)
    new_child.school_years.create!(label: "2025/2026", user: @child.user)
    new_child.notifications.create!(user: @child.user, title: "Test", body: "Body")

    assert_difference [ "MealTicket.count", "MealDetail.count", "SaldoRecord.count", "SchoolYear.count", "Notification.count" ], -1 do
      new_child.destroy
    end
  end
end
