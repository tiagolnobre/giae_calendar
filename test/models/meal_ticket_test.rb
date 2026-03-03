require "test_helper"

class MealTicketTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_login_url: "https://test.giae.pt",
      giae_username: "testuser",
      giae_password: "testpass"
    )
  end

  test "should be valid with required attributes" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true)
    assert ticket.valid?
  end

  test "date should be present" do
    ticket = MealTicket.new(user: @user, bought: true)
    assert_not ticket.valid?
    assert ticket.errors[:date].any?
  end

  test "bought should be present" do
    ticket = MealTicket.new(user: @user, date: Date.today)
    assert_not ticket.valid?
    assert ticket.errors[:bought].any?
  end

  test "bought should be boolean" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true)
    assert ticket.valid?

    ticket.bought = false
    assert ticket.valid?
  end

  test "should have unique user and date combination" do
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    duplicate = MealTicket.new(user: @user, date: Date.today, bought: false)
    assert_not duplicate.valid?
    assert duplicate.errors[:date].any?
  end

  test "different users can have same date" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_login_url: "https://test.giae.pt",
      giae_username: "other",
      giae_password: "pass"
    )
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    other_ticket = MealTicket.new(user: other_user, date: Date.today, bought: false)
    assert other_ticket.valid?
  end

  test "scope bought_tickets should return bought tickets" do
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    MealTicket.create!(user: @user, date: Date.today + 1.day, bought: false)

    assert_equal 1, @user.meal_tickets.bought_tickets.count
    assert_equal Date.today, @user.meal_tickets.bought_tickets.first.date
  end

  test "scope not_bought_tickets should return not bought tickets" do
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    MealTicket.create!(user: @user, date: Date.today + 1.day, bought: false)

    assert_equal 1, @user.meal_tickets.not_bought_tickets.count
    assert_equal Date.today + 1.day, @user.meal_tickets.not_bought_tickets.first.date
  end
end
