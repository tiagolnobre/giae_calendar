require "test_helper"

class MealDetailTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @child = children(:one)
    @meal_detail = MealDetail.new(
      child: @child,
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
    @meal_detail.save!
    assert_equal @user, @meal_detail.user
  end

  test "should belong to child" do
    assert_equal @child, @meal_detail.child
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

  test "should enforce unique date and period per child" do
    @meal_detail.save!
    duplicate = MealDetail.new(
      child: @child,
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
      child: @child,
      date: Date.today,
      period: "Jantar",
      soup: "Sopa de Feijão"
    )
    assert other_period.valid?
  end

  test "same period on different dates should be valid" do
    @meal_detail.save!
    other_date = MealDetail.new(
      child: @child,
      date: Date.tomorrow,
      period: "Almoço",
      soup: "Sopa de Feijão"
    )
    assert other_date.valid?
  end

  test "same date and period for different children should be valid" do
    @meal_detail.save!
    other_child = children(:two)
    other_child_detail = MealDetail.new(
      child: other_child,
      date: Date.today,
      period: "Almoço",
      soup: "Sopa de Feijão"
    )
    assert other_child_detail.valid?
  end
end