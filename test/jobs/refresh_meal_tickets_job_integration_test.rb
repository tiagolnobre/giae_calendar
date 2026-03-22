# frozen_string_literal: true

require "test_helper"

class RefreshMealTicketsJobIntegrationTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      giae_username: "test_user",
      giae_password: "test_pass",
      giae_school_code: "161676"
    )
    @job = RefreshMealTicketsJob.new
    # Use a real cache for these tests since around_enqueue uses Rails.cache
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "around_enqueue prevents duplicate jobs" do
    # First enqueue should succeed
    assert_enqueued_with(job: RefreshMealTicketsJob) do
      RefreshMealTicketsJob.perform_later(@user)
    end

    # Simulate job in progress
    Rails.cache.write("refresh_meal_tickets_#{@user.id}", true)

    # Second enqueue should be skipped
    assert_no_enqueued_jobs do
      RefreshMealTicketsJob.perform_later(@user)
    end

    Rails.cache.delete("refresh_meal_tickets_#{@user.id}")
  end

  test "around_enqueue cleans up cache on success" do
    RefreshMealTicketsJob.perform_later(@user)
    assert Rails.cache.exist?("refresh_meal_tickets_#{@user.id}")

    perform_enqueued_jobs
    assert_not Rails.cache.exist?("refresh_meal_tickets_#{@user.id}")
  end

  test "around_enqueue cleans up cache on failure" do
    RefreshMealTicketsJob.perform_later(@user)

    # Simulate job failure
    RefreshMealTicketsJob.any_instance.stubs(:perform).raises(StandardError)

    begin
      perform_enqueued_jobs
    rescue
      # Expected
    end

    assert_not Rails.cache.exist?("refresh_meal_tickets_#{@user.id}")
  end

  test "job handles integer user id" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([])
    mock_scraper.expects(:fetch_meal_details).returns({})

    GiaeScraperService.expects(:new).returns(mock_scraper)

    @job.perform(@user.id)
  end

  test "job handles User object" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "meat" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({})

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_difference "MealTicket.count", 1 do
      @job.perform(@user)
    end
  end

  test "job creates meal details when available" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "fish" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({
      Date.today => {
        descricaoperiodo: "Lunch",
        soup: "Vegetable Soup",
        main_dish: "Grilled Fish",
        vegetables: "Potatoes",
        dessert: "Fruit",
        bread: "Yes"
      }
    })

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_difference "MealTicket.count", 1 do
      assert_difference "MealDetail.count", 1 do
        @job.perform(@user)
      end
    end
  end

  test "job updates last_refreshed_at timestamp" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([])
    mock_scraper.expects(:fetch_meal_details).returns({})

    GiaeScraperService.expects(:new).returns(mock_scraper)

    @job.perform(@user)

    @user.reload
    assert @user.last_refreshed_at.present?
    assert_in_delta Time.current, @user.last_refreshed_at, 1.second
  end

  test "job handles session unavailable" do
    GiaeSessionManager.any_instance.expects(:with_active_session).raises(
      GiaeSessionManager::SessionUnavailable, "Session expired"
    )

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end

  test "job updates existing tickets" do
    existing = MealTicket.create!(
      user: @user,
      date: Date.today,
      bought: false,
      dish_type: "meat"
    )

    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "fish" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({})

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_no_difference "MealTicket.count" do
      @job.perform(@user)
    end

    existing.reload
    assert existing.bought
    assert_equal "fish", existing.dish_type
  end

  test "job handles missing meal details gracefully" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "meat" }
    ])
    mock_scraper.expects(:fetch_meal_details).raises(StandardError, "Network error")

    GiaeScraperService.expects(:new).returns(mock_scraper)

    assert_difference "MealTicket.count", 1 do
      assert_no_difference "MealDetail.count" do
        @job.perform(@user)
      end
    end
  end
end
