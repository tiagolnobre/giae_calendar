require "test_helper"

class MealTicketTest < ActiveSupport::TestCase
  setup do
    MealTicket.delete_all
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
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

  test "dish_type validates allowed values" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true)

    # Valid values
    ticket.dish_type = "meat"
    assert ticket.valid?

    ticket.dish_type = "fish"
    assert ticket.valid?

    ticket.dish_type = nil
    assert ticket.valid?

    # Invalid value
    ticket.dish_type = "vegetarian"
    assert_not ticket.valid?
    assert ticket.errors[:dish_type].any?
  end

  test "dish_type_icon returns meat icon for meat dishes" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true, dish_type: "meat")
    assert ticket.dish_type_icon.present?
    assert_includes ticket.dish_type_icon, "lucide-beef"
    assert ticket.dish_type_icon.html_safe?
  end

  test "dish_type_icon returns fish icon for fish dishes" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true, dish_type: "fish")
    assert ticket.dish_type_icon.present?
    assert_includes ticket.dish_type_icon, "lucide-fish"
    assert ticket.dish_type_icon.html_safe?
  end

  test "dish_type_icon returns nil for unknown dish type" do
    ticket = MealTicket.new(user: @user, date: Date.today, bought: true, dish_type: nil)
    assert_nil ticket.dish_type_icon
  end

  test "FISH_ICON constant is defined" do
    assert MealTicket::FISH_ICON.present?
    assert_includes MealTicket::FISH_ICON, "lucide-fish"
    assert MealTicket::FISH_ICON.html_safe?
  end

  test "MEAT_ICON constant is defined" do
    assert MealTicket::MEAT_ICON.present?
    assert_includes MealTicket::MEAT_ICON, "lucide-beef"
    assert MealTicket::MEAT_ICON.html_safe?
  end

  test "belongs to user" do
    ticket = MealTicket.create!(user: @user, date: Date.today, bought: true)
    assert_equal @user, ticket.user
  end

  test "user can have multiple tickets" do
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    MealTicket.create!(user: @user, date: Date.today + 1.day, bought: true)
    MealTicket.create!(user: @user, date: Date.today + 2.days, bought: false)

    assert_equal 3, @user.meal_tickets.count
  end

  test "bought scope excludes not bought tickets" do
    bought = MealTicket.create!(user: @user, date: Date.today, bought: true)
    MealTicket.create!(user: @user, date: Date.today + 1.day, bought: false)

    assert_includes MealTicket.bought_tickets, bought
    assert_equal 1, MealTicket.bought_tickets.count
  end

  test "not_bought scope excludes bought tickets" do
    MealTicket.create!(user: @user, date: Date.today, bought: true)
    not_bought = MealTicket.create!(user: @user, date: Date.today + 1.day, bought: false)

    assert_includes MealTicket.not_bought_tickets, not_bought
    assert_equal 1, MealTicket.not_bought_tickets.count
  end

  test "can update bought status" do
    ticket = MealTicket.create!(user: @user, date: Date.today, bought: true)
    ticket.update!(bought: false)

    ticket.reload
    assert_not ticket.bought
  end

  test "can update dish_type" do
    ticket = MealTicket.create!(user: @user, date: Date.today, bought: true, dish_type: "meat")
    ticket.update!(dish_type: "fish")

    ticket.reload
    assert_equal "fish", ticket.dish_type
  end
end
