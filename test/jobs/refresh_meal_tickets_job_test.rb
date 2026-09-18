# frozen_string_literal: true

require "test_helper"

class RefreshMealTicketsJobTest < ActiveJob::TestCase
  setup do
    @child = children(:one)
    @child.update!(giae_username: "testuser", giae_password: "testpass")
    @job = RefreshMealTicketsJob.new
    # Use a real cache for these tests since around_enqueue uses Rails.cache
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "job is enqueued with correct queue" do
    assert_equal "default", RefreshMealTicketsJob.queue_name
  end

  test "around_enqueue prevents duplicate jobs for same child" do
    # First job should enqueue
    assert_enqueued_with(job: RefreshMealTicketsJob, args: [ @child ]) do
      RefreshMealTicketsJob.perform_later(@child)
    end

    # Set the cache key to simulate running job
    Rails.cache.write("refresh_meal_tickets_#{@child.id}", true)

    # Second job should be skipped
    assert_no_enqueued_jobs do
      RefreshMealTicketsJob.perform_later(@child)
    end
  end

  test "around_enqueue cleans up cache after job completes" do
    # The cache is used during enqueue to prevent duplicate jobs, then cleaned up immediately
    # Cache is written before job is enqueued and deleted in ensure block after
    cache_key = "refresh_meal_tickets_#{@child.id}"

    # Verify job is enqueued and cache is cleaned up
    assert_enqueued_jobs 1 do
      RefreshMealTicketsJob.perform_later(@child)
    end

    # Cache should be cleaned up immediately after enqueue (in ensure block)
    assert_not Rails.cache.exist?(cache_key)

    # Job should still execute normally
    perform_enqueued_jobs
  end

  test "perform handles child passed as Child object" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "meat" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({})

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    assert_difference "MealTicket.count", 1 do
      @job.perform(@child)
    end

    ticket = MealTicket.last
    assert_equal @child.id, ticket.child_id
    assert_equal @child.user_id, ticket.user_id
    assert_equal Date.today, ticket.date
    assert ticket.bought
    assert_equal "meat", ticket.dish_type
  end

  test "perform handles child passed as integer id" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([])
    mock_scraper.expects(:fetch_meal_details).returns({})

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    assert_no_difference "MealTicket.count" do
      @job.perform(@child.id)
    end
  end

  test "perform creates meal details when available" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "fish" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({
      Date.today => [
        {
          period: "Almoço",
          soup: "Sopa de Legumes",
          main_dish: "Peixe Grelhado",
          vegetables: "Batatas Cozidas",
          dessert: "Fruta",
          bread: "Pão"
        }
      ]
    })

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    assert_difference "MealTicket.count", 1 do
      assert_difference "MealDetail.count", 1 do
        @job.perform(@child)
      end
    end

    detail = MealDetail.last
    assert_equal "Almoço", detail.period
    assert_equal "Sopa de Legumes", detail.soup
    assert_equal "Peixe Grelhado", detail.main_dish
  end

  test "perform creates one meal detail per menu option" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "fish" }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({
      Date.today => [
        { period: "Almoço", soup: "Sopa", main_dish: "Peixe Grelhado", vegetables: nil, dessert: nil, bread: nil },
        { period: "Almoço Vegetariano", soup: "Sopa", main_dish: "Tofu", vegetables: nil, dessert: nil, bread: nil }
      ]
    })

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    assert_difference "MealDetail.count", 2 do
      @job.perform(@child)
    end

    periods = @child.meal_details.where(date: Date.today).order(:period).pluck(:period)
    assert_equal [ "Almoço", "Almoço Vegetariano" ], periods
  end

  test "perform updates existing tickets" do
    existing_ticket = meal_tickets(:one)

    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: existing_ticket.date, bought: false, dish_type: nil }
    ])
    mock_scraper.expects(:fetch_meal_details).returns({})

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    assert_no_difference "MealTicket.count" do
      @job.perform(@child)
    end

    existing_ticket.reload
    assert_not existing_ticket.bought
    assert_nil existing_ticket.dish_type
  end

  test "perform updates child's last_refreshed_at timestamp" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([])
    mock_scraper.expects(:fetch_meal_details).returns({})

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    @job.perform(@child)

    @child.reload
    assert @child.last_refreshed_at.present?
    assert_in_delta Time.current, @child.last_refreshed_at, 1.second
  end

  test "perform handles missing meal details gracefully" do
    mock_scraper = mock("scraper")
    mock_scraper.expects(:fetch_refeicoes_compra).returns([
      { date: Date.today, bought: true, dish_type: "meat" }
    ])
    mock_scraper.expects(:fetch_meal_details).raises(StandardError, "Details unavailable")

    @job.expects(:with_session).with(@child).yields(mock_scraper)

    # Should not raise error, should create ticket without details
    assert_difference "MealTicket.count", 1 do
      assert_no_difference "MealDetail.count" do
        @job.perform(@child)
      end
    end
  end

  test "perform re-raises SessionUnavailable error" do
    @job.expects(:with_session).with(@child).raises(GiaeSessionManager::SessionUnavailable, "Session expired")

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@child)
    end
  end
end