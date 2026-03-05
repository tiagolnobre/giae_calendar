require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
  end

  test "should get show" do
    get calendar_path
    assert_response :success
    assert_select "h1", I18n.t("calendar.meals")
  end

  test "should redirect to sign_in when not authenticated" do
    delete sign_out_path
    get calendar_path
    assert_redirected_to %r{/sign_in}
  end

  test "should display calendar with current month" do
    get calendar_path
    assert_response :success
    # Check for month name in the page
    assert_select ".text-lg.font-semibold", Date.today.strftime("%B %Y")
  end

  test "should navigate to previous month" do
    get calendar_path(month: Date.today.month - 1, year: Date.today.year)
    assert_response :success
  end

  test "should navigate to next month" do
    get calendar_path(month: Date.today.month + 1, year: Date.today.year)
    assert_response :success
  end

  test "should refresh calendar" do
    post refresh_calendar_path
    assert_redirected_to %r{/calendar}
  end

  test "should display today's menu when available" do
    MealDetail.create!(
      user: @user,
      date: Date.today,
      period: "Almoço",
      soup: "Sopa de Legumes",
      main_dish: "Frango Assado"
    )

    get calendar_path
    assert_response :success
    assert_select "h3", I18n.t("calendar.today_menu")
  end
end
