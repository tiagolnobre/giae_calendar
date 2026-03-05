require "test_helper"

class MealDetailTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @meal_detail = MealDetail.new(
      user: @user,
      date: Date.today,
      period: "Almoço",
      soup: "Sopa de Legumes",
      main_dish: "Frango Assado",
      vegetables: "Salada",
      bread: "Pão",
      dessert: "Fruta"
    )
  end

  test "should be valid with all required attributes" do
    assert @meal_detail.valid?
  end

  test "should belong to user" do
    assert_equal @user, @meal_detail.user
  end

  test "date should be present" do
    @meal_detail.date = nil
    assert_not @meal_detail.valid?
    assert @meal_detail.errors[:date].any?
  end

  test "period should be present" do
    @meal_detail.period = nil
    assert_not @meal_detail.valid?
    assert @meal_detail.errors[:period].any?
  end

  test "should enforce unique date and period per user" do
    @meal_detail.save!
    duplicate = MealDetail.new(
      user: @user,
      date: Date.today,
      period: "Almoço",
      soup: "Sopa de Feijão"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:date].any?
  end

  test "different periods on same date should be valid" do
    @meal_detail.save!
    other_period = MealDetail.new(
      user: @user,
      date: Date.today,
      period: "Jantar",
      soup: "Sopa de Feijão"
    )
    assert other_period.valid?
  end

  test "same period on different dates should be valid" do
    @meal_detail.save!
    other_date = MealDetail.new(
      user: @user,
      date: Date.tomorrow,
      period: "Almoço",
      soup: "Sopa de Feijão"
    )
    assert other_date.valid?
  end

  test "same date and period for different users should be valid" do
    @meal_detail.save!
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "otheruser",
      giae_password: "otherpass"
    )
    other_user_detail = MealDetail.new(
      user: other_user,
      date: Date.today,
      period: "Almoço",
      soup: "Sopa de Feijão"
    )
    assert other_user_detail.valid?
  end
end
