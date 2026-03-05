require "test_helper"

class CleanupGiaeSessionsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "should delete old sessions" do
    # Create an old session
    old_session = GiaeSession.create!(
      user: @user,
      status: :active,
      updated_at: 25.hours.ago
    )

    assert_difference "GiaeSession.count", -1 do
      CleanupGiaeSessionsJob.perform_now
    end

    assert_nil GiaeSession.find_by(id: old_session.id)
  end

  test "should not delete recent sessions" do
    recent_session = GiaeSession.create!(
      user: @user,
      status: :active,
      updated_at: 1.hour.ago
    )

    assert_no_difference "GiaeSession.count" do
      CleanupGiaeSessionsJob.perform_now
    end

    assert GiaeSession.exists?(recent_session.id)
  end

  test "should reset stuck refreshing sessions" do
    stuck_session = GiaeSession.create!(
      user: @user,
      status: :refreshing,
      locked_at: (GiaeSessionManager::LOCK_TIMEOUT + 1.minute).ago
    )

    assert stuck_session.refreshing?

    CleanupGiaeSessionsJob.perform_now

    stuck_session.reload
    assert stuck_session.failed?
    assert stuck_session.error_message.include?("Lock timed out")
  end

  test "should not reset non-stuck refreshing sessions" do
    valid_session = GiaeSession.create!(
      user: @user,
      status: :refreshing,
      locked_at: 10.seconds.ago
    )

    assert valid_session.refreshing?

    CleanupGiaeSessionsJob.perform_now

    valid_session.reload
    assert valid_session.refreshing?
  end

  test "should handle empty sessions gracefully" do
    GiaeSession.destroy_all

    assert_no_difference "GiaeSession.count" do
      CleanupGiaeSessionsJob.perform_now
    end
  end

  test "should log cleanup information" do
    GiaeSession.create!(user: @user, status: :active, updated_at: 25.hours.ago)

    # Just ensure the job runs without error when logging
    assert_nothing_raised do
      CleanupGiaeSessionsJob.perform_now
    end
  end
end
