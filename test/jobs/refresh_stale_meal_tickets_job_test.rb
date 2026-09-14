require "test_helper"

class RefreshStaleMealTicketsJobTest < ActiveJob::TestCase
  test "should queue refresh for children with stale data" do
    # Ensure all children have fresh data first
    Child.update_all(last_refreshed_at: Time.current)

    Child.where(id: children(:one).id).update_all(last_refreshed_at: 5.hours.ago)

    assert_enqueued_with(job: RefreshMealTicketsJob) do
      RefreshStaleMealTicketsJob.perform_now
    end
  end

  test "should queue refresh for children with no refresh data" do
    # Ensure all children have fresh data first
    Child.update_all(last_refreshed_at: Time.current)

    Child.where(id: children(:two).id).update_all(last_refreshed_at: nil)

    assert_enqueued_with(job: RefreshMealTicketsJob) do
      RefreshStaleMealTicketsJob.perform_now
    end
  end

  test "should not queue refresh for children with fresh data" do
    # Ensure ALL children have fresh data
    Child.update_all(last_refreshed_at: Time.current)

    enqueued_jobs.clear
    RefreshStaleMealTicketsJob.perform_now

    # No RefreshMealTicketsJob should be enqueued
    refresh_jobs = enqueued_jobs.select { |j| j[:job] == RefreshMealTicketsJob }
    assert_equal 0, refresh_jobs.count
  end

  test "should not enqueue NotifyUpcomingMealTicketsJob" do
    Child.update_all(last_refreshed_at: Time.current)
    Child.where(id: children(:one).id).update_all(last_refreshed_at: 5.hours.ago)

    enqueued_jobs.clear
    RefreshStaleMealTicketsJob.perform_now

    notify_jobs = enqueued_jobs.select { |j| j[:job] == NotifyUpcomingMealTicketsJob }
    assert_equal 0, notify_jobs.count
  end

  test "should handle multiple stale children" do
    Child.update_all(last_refreshed_at: Time.current)
    Child.where(id: [ children(:one).id, children(:two).id ]).update_all(last_refreshed_at: 10.hours.ago)

    RefreshStaleMealTicketsJob.perform_now

    # Should have 2 RefreshMealTicketsJob only
    refresh_jobs = enqueued_jobs.select { |j| j[:job] == RefreshMealTicketsJob }
    assert_equal 2, refresh_jobs.count
  end

  test "should handle no stale children" do
    Child.update_all(last_refreshed_at: Time.current)

    enqueued_jobs.clear
    RefreshStaleMealTicketsJob.perform_now

    refresh_jobs = enqueued_jobs.select { |j| j[:job] == RefreshMealTicketsJob }
    assert_equal 0, refresh_jobs.count
  end
end