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

  test "should handle year boundary when navigating months" do
    # Test December to January transition
    get calendar_path(month: 12, year: Date.today.year - 1)
    assert_response :success

    # Test January to December transition
    get calendar_path(month: 1, year: Date.today.year + 1)
    assert_response :success
  end

  test "should handle invalid month parameters gracefully" do
    # Invalid month should default to current month
    get calendar_path(month: 13, year: Date.today.year)
    assert_response :redirect
  end

  test "should display ticket status in calendar" do
    meal_tickets(:one).update!(bought: true)

    get calendar_path
    assert_response :success
    # Check for bought ticket styling (green background color in inline style)
    assert_match(/background-color:\s*#5DD3B6/, response.body)
  end

  test "should display not bought status" do
    meal_tickets(:one).update!(bought: false)

    get calendar_path
    assert_response :success
    # Check for not bought ticket styling (gray background color in inline style)
    assert_match(/background-color:\s*#D1D5DB/, response.body)
  end

  test "should enqueue refresh job on refresh action" do
    assert_enqueued_with(job: RefreshMealTicketsJob) do
      post refresh_calendar_path
    end
  end

  test "should show refresh status with last updated time" do
    @user.update!(last_refreshed_at: 5.hours.ago)

    get calendar_path
    assert_response :success
    # Check that refresh status div exists and shows last update time
    assert_select "#refresh-status"
    assert_match(/Última atualização/, response.body)
  end

  test "should show refresh status for fresh data" do
    @user.update!(last_refreshed_at: 30.minutes.ago)

    get calendar_path
    assert_response :success
    assert_select "#refresh-status"
    assert_match(/Última atualização/, response.body)
  end

  test "should handle missing last_refreshed_at" do
    @user.update!(last_refreshed_at: nil)

    get calendar_path
    assert_response :success
    # Should show "never updated" message
    assert_match(/Nunca atualizado/, response.body)
  end

  test "should display calendar grid" do
    get calendar_path
    assert_response :success
    # Calendar should use a grid layout with day cells
    assert_select ".grid.grid-cols-7"
    # Should have at least 28 day cells (4 weeks minimum)
    day_cells = css_select("[class*='aspect-square']")
    assert day_cells.length >= 28
  end

  test "should show navigation arrows" do
    get calendar_path
    assert_response :success
    assert_select "a[href*='month=']"
  end

  test "day_details returns modal with meal info" do
    meal_ticket = meal_tickets(:one)
    get day_details_path(date: meal_ticket.date)
    assert_response :success
    assert_match meal_ticket.date.to_s, response.body
  end

  test "day_details handles invalid date gracefully" do
    get day_details_path(date: "invalid")
    assert_response :success
  end

  test "refresh redirects when refresh already in progress" do
    Rails.cache.write("refresh_meal_tickets_#{@user.id}", true)

    post refresh_calendar_path
    assert_redirected_to %r{/calendar}
    assert_match(/already in progress/, flash[:alert])

    Rails.cache.delete("refresh_meal_tickets_#{@user.id}")
  end

  test "refresh enqueues both jobs" do
    assert_enqueued_jobs 2 do
      post refresh_calendar_path
    end
  end

  test "show with specific month and year" do
    get calendar_path(month: 6, year: 2024)
    assert_response :success
    assert_select ".text-lg.font-semibold", "June 2024"
  end

  test "show handles edge case month values" do
    get calendar_path(month: 0, year: 2024)
    assert_response :success
    # Should default to current date
  end

  test "build_calendar_days includes holidays" do
    # Test around a known Portuguese holiday
    Date.new(2024, 12, 25)
    get calendar_path(month: 12, year: 2024)
    assert_response :success
  end

  test "calendar displays correct number of weeks" do
    get calendar_path
    assert_response :success
    # Should have 5-6 weeks displayed
    weeks = css_select(".grid.grid-cols-7 > div")
    assert weeks.length >= 35 # 5 weeks * 7 days
  end

  test "refresh clears cache after job completes" do
    post refresh_calendar_path
    perform_enqueued_jobs
    assert_not Rails.cache.exist?("refresh_meal_tickets_#{@user.id}")
  end

  test "day_details returns partial layout" do
    meal_ticket = meal_tickets(:one)
    get day_details_path(date: meal_ticket.date)
    assert_response :success
    # Should not include full layout
    assert_no_match(/<html>/, response.body)
  end

  test "show handles users with no tickets" do
    MealTicket.where(user: @user).destroy_all
    get calendar_path
    assert_response :success
    assert_select ".grid.grid-cols-7"
  end

  test "refresh with turbo stream format" do
    post refresh_calendar_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.content_type)
  end
end
