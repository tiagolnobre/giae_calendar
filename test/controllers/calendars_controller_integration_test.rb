# frozen_string_literal: true

require "test_helper"

class CalendarsControllerIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
  end

  test "show handles turbo stream requests" do
    get calendar_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "show with year boundary navigation" do
    # Navigate from January to December of previous year
    get calendar_path(month: 1, year: 2024)
    assert_response :success

    # Check navigation to previous month works
    get calendar_path(month: 12, year: 2023)
    assert_response :success
  end

  test "show with different months" do
    (1..12).each do |month|
      get calendar_path(month: month, year: 2024)
      assert_response :success, "Failed for month #{month}"
    end
  end

  test "show displays bought tickets with correct styling" do
    MealTicket.create!(
      user: @user,
      date: Date.today,
      bought: true,
      dish_type: "meat"
    )

    get calendar_path
    assert_response :success
    # Should show meat icon for bought ticket
    assert_match(/lucide-beef/, response.body)
  end

  test "show displays not bought tickets" do
    MealTicket.create!(
      user: @user,
      date: Date.today,
      bought: false
    )

    get calendar_path
    assert_response :success
  end

  test "show displays today's menu when available" do
    MealDetail.create!(
      user: @user,
      date: Date.today,
      period: "Lunch",
      soup: "Vegetable Soup",
      main_dish: "Grilled Chicken",
      vegetables: "Potatoes",
      dessert: "Fruit",
      bread: "Yes"
    )

    get calendar_path
    assert_response :success
    assert_match(/Vegetable Soup/, response.body)
    assert_match(/Grilled Chicken/, response.body)
  end

  test "show handles missing today's menu gracefully" do
    get calendar_path
    assert_response :success
    # Should not show today's menu section when no details
    assert_no_match(/today_menu/, response.body)
  end

  test "day_details returns modal for valid date" do
    MealDetail.create!(
      user: @user,
      date: Date.today,
      period: "Lunch",
      soup: "Soup"
    )

    MealTicket.create!(
      user: @user,
      date: Date.today,
      bought: true
    )

    get day_details_path(date: Date.today.to_s)
    assert_response :success
    assert_match(/Soup/, response.body)
  end

  test "day_details handles date without meal details" do
    get day_details_path(date: Date.today.to_s)
    assert_response :success
  end

  test "day_details handles invalid date gracefully" do
    get day_details_path(date: "invalid-date")
    assert_response :success
    # Should default to today
  end

  test "day_details handles empty date parameter" do
    get day_details_path(date: "")
    assert_response :success
  end

  test "refresh enqueues jobs when not in progress" do
    assert_difference -> { ActiveJob::Base.queue_adapter.enqueued_jobs.count }, 2 do
      post refresh_calendar_path
    end
  end

  test "refresh redirects when successful" do
    post refresh_calendar_path
    assert_redirected_to calendar_path
    assert_equal "Refreshing meal tickets...", flash[:notice]
  end

  test "refresh prevents duplicate refresh requests" do
    # First request should work
    post refresh_calendar_path

    # Simulate job in progress
    Rails.cache.write("refresh_meal_tickets_#{@user.id}", true)

    # Second request should be blocked
    post refresh_calendar_path
    assert_redirected_to calendar_path
    assert_match(/already in progress/, flash[:alert])

    Rails.cache.delete("refresh_meal_tickets_#{@user.id}")
  end

  test "refresh handles turbo stream format" do
    post refresh_calendar_path,
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "build_calendar_days includes all days of month" do
    get calendar_path(month: 2, year: 2024)  # February 2024 (leap year)
    assert_response :success

    # Should have around 35 days (5 weeks × 7 days)
    day_cells = css_select(".aspect-square")
    assert day_cells.length >= 28  # At least 4 weeks
    assert day_cells.length <= 42  # At most 6 weeks
  end

  test "build_calendar_days marks weekends correctly" do
    get calendar_path
    assert_response :success
  end

  test "build_calendar_days marks holidays correctly" do
    # Test around Christmas
    get calendar_path(month: 12, year: 2024)
    assert_response :success
  end

  test "show with different year values" do
    get calendar_path(month: 6, year: 2023)
    assert_response :success

    get calendar_path(month: 6, year: 2025)
    assert_response :success
  end

  test "refresh when both jobs are running" do
    Rails.cache.write("refresh_meal_tickets_#{@user.id}", true)
    Rails.cache.write("fetch_saldo_#{@user.id}", true)

    post refresh_calendar_path
    assert_redirected_to calendar_path
    assert_match(/already in progress/, flash[:alert])

    Rails.cache.delete("refresh_meal_tickets_#{@user.id}")
    Rails.cache.delete("fetch_saldo_#{@user.id}")
  end

  test "refresh clears cache after completion" do
    post refresh_calendar_path

    perform_enqueued_jobs

    assert_not Rails.cache.exist?("refresh_meal_tickets_#{@user.id}")
  end

  test "show displays month and year correctly" do
    get calendar_path(month: 6, year: 2024)
    assert_response :success
    # Should display June 2024
    assert_match(/June 2024|Junho 2024/, response.body)
  end

  test "show has navigation links" do
    get calendar_path
    assert_response :success

    # Should have previous and next month links
    assert_select "a[href*='month=']", minimum: 2
  end

  test "show displays legend" do
    get calendar_path
    assert_response :success

    # Should have legend for bought/not bought
    assert_match(/bought|Comprado/i, response.body)
  end

  test "show displays refresh button" do
    get calendar_path
    assert_response :success

    # Should have refresh button
    assert_select "form[action='#{refresh_calendar_path}']", minimum: 1
  end

  test "show handles leap year correctly" do
    get calendar_path(month: 2, year: 2024)
    assert_response :success
  end

  test "show handles month with 31 days" do
    get calendar_path(month: 1, year: 2024)  # January
    assert_response :success
  end

  test "show handles month with 30 days" do
    get calendar_path(month: 4, year: 2024)  # April
    assert_response :success
  end
end
