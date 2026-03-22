require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "testuser",
      giae_password: "testpass"
    )
  end

  test "should be valid with all required attributes" do
    assert @user.valid?
  end

  test "email should be present" do
    @user.email = ""
    assert_not @user.valid?
    assert @user.errors[:email].any?
  end

  test "email should be unique" do
    duplicate = @user.dup
    @user.save
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test "password should be present" do
    @user.password = nil
    @user.password_confirmation = nil
    assert_not @user.valid?
    assert @user.errors[:password].any?
  end

  test "password should match confirmation" do
    @user.password_confirmation = "different"
    assert_not @user.valid?
    assert @user.errors[:password_confirmation].any?
  end

  test "should authenticate with correct password" do
    @user.save!
    authenticated = User.find_by(email: "test@example.com").authenticate("password123")
    assert authenticated
  end

  test "should not authenticate with incorrect password" do
    @user.save!
    authenticated = User.find_by(email: "test@example.com").authenticate("wrongpassword")
    assert_not authenticated
  end

  test "should destroy associated meal tickets" do
    @user.save!
    @user.meal_tickets.create!(date: Date.today, bought: true)
    assert_difference "MealTicket.count", -1 do
      @user.destroy
    end
  end

  test "should enqueue RefreshMealTicketsJob on create" do
    assert_enqueued_with(job: RefreshMealTicketsJob) do
      @user.save!
    end
  end

  test "should enqueue FetchSaldoDisponivelJob on create" do
    assert_enqueued_with(job: FetchSaldoDisponivelJob) do
      @user.save!
    end
  end

  test "remember_me! generates token and returns it" do
    @user.save!
    token = @user.remember_me!

    assert token.present?
    assert_equal 32, Base64.urlsafe_decode64(token).length
    assert @user.remember_token.present?
    assert @user.remember_created_at.present?
  end

  test "remember_me! updates remember_created_at timestamp" do
    @user.save!
    before_time = Time.current
    @user.remember_me!

    assert @user.remember_created_at >= before_time
  end

  test "forget_me! clears remember token" do
    @user.save!
    @user.remember_me!
    @user.forget_me!

    assert_nil @user.remember_token
    assert_nil @user.remember_created_at
  end

  test "remember_token_valid? returns true for valid token" do
    @user.save!
    token = @user.remember_me!

    assert @user.remember_token_valid?(token)
  end

  test "remember_token_valid? returns false for nil token" do
    @user.save!
    assert_not @user.remember_token_valid?(nil)
  end

  test "remember_token_valid? returns false for wrong token" do
    @user.save!
    @user.remember_me!

    assert_not @user.remember_token_valid?("wrong_token")
  end

  test "remember_token_valid? returns false for expired token" do
    @user.save!
    token = @user.remember_me!
    @user.update!(remember_created_at: 3.weeks.ago)

    assert_not @user.remember_token_valid?(token)
  end

  test "remember_token_valid? returns false when remember_created_at is nil" do
    @user.save!
    @user.update!(remember_token: "some_token", remember_created_at: nil)

    assert_not @user.remember_token_valid?("some_token")
  end

  test "meal_tickets_for_month returns tickets for specified month" do
    @user.save!

    # Create tickets for different months
    january_ticket = @user.meal_tickets.create!(date: Date.new(2024, 1, 15), bought: true)
    february_ticket = @user.meal_tickets.create!(date: Date.new(2024, 2, 10), bought: true)

    january_tickets = @user.meal_tickets_for_month(1, 2024)

    assert_includes january_tickets, january_ticket
    assert_not_includes january_tickets, february_ticket
  end

  test "meal_tickets_for_month orders by date" do
    @user.save!

    ticket1 = @user.meal_tickets.create!(date: Date.new(2024, 1, 10), bought: true)
    ticket2 = @user.meal_tickets.create!(date: Date.new(2024, 1, 5), bought: true)
    ticket3 = @user.meal_tickets.create!(date: Date.new(2024, 1, 20), bought: true)

    tickets = @user.meal_tickets_for_month(1, 2024).to_a
    assert_equal [ ticket2, ticket1, ticket3 ], tickets
  end

  test "current_month_tickets returns tickets for current month" do
    @user.save!
    today = Date.today

    current_ticket = @user.meal_tickets.create!(date: today, bought: true)
    other_ticket = @user.meal_tickets.create!(date: today.prev_month, bought: true)

    current_tickets = @user.current_month_tickets

    assert_includes current_tickets, current_ticket
    assert_not_includes current_tickets, other_ticket
  end

  test "unread_notifications returns unread notifications in reverse chronological order" do
    @user.save!

    old_unread = @user.notifications.create!(title: "Old", body: "Body", read_at: nil, created_at: 2.days.ago)
    new_unread = @user.notifications.create!(title: "New", body: "Body", read_at: nil, created_at: 1.day.ago)
    read_notification = @user.notifications.create!(title: "Read", body: "Body", read_at: Time.current)

    unread = @user.unread_notifications

    assert_includes unread, old_unread
    assert_includes unread, new_unread
    assert_not_includes unread, read_notification
    assert_equal [ new_unread, old_unread ], unread.to_a  # Reverse chronological (newest first)
  end

  test "unread_notification_count returns count of unread notifications" do
    @user.save!

    @user.notifications.create!(title: "Unread 1", body: "Body", read_at: nil)
    @user.notifications.create!(title: "Unread 2", body: "Body", read_at: nil)
    @user.notifications.create!(title: "Read", body: "Body", read_at: Time.current)

    assert_equal 2, @user.unread_notification_count
  end

  test "unread_notification_count returns 0 when no unread notifications" do
    @user.save!
    @user.notifications.create!(title: "Read", body: "Body", read_at: Time.current)

    assert_equal 0, @user.unread_notification_count
  end

  test "refresh_in_progress? returns true when meal ticket refresh is running" do
    @user.save!
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("refresh_meal_tickets_#{@user.id}", true)

    assert @user.refresh_in_progress?

    Rails.cache = original_cache
  end

  test "refresh_in_progress? returns true when saldo fetch is running" do
    @user.save!
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("fetch_saldo_#{@user.id}", true)

    assert @user.refresh_in_progress?

    Rails.cache = original_cache
  end

  test "refresh_in_progress? returns false when no refresh is running" do
    @user.save!

    assert_not @user.refresh_in_progress?
  end

  test "set_default_school_code sets default on create" do
    user = User.create!(
      email: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "newuser",
      giae_password: "newpass"
    )

    assert_equal User::DEFAULT_SCHOOL_CODE, user.giae_school_code
  end

  test "set_default_school_code preserves custom school code" do
    user = User.create!(
      email: "custom@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "custom",
      giae_password: "pass",
      giae_school_code: "999999"
    )

    assert_equal "999999", user.giae_school_code
  end

  test "REMEMBER_EXPIRATION is set to 2 weeks" do
    assert_equal 2.weeks, User::REMEMBER_EXPIRATION
  end

  test "DEFAULT_SCHOOL_CODE is set" do
    assert_equal "161676", User::DEFAULT_SCHOOL_CODE
  end

  test "has_many meal_tickets association" do
    @user.save!
    ticket = @user.meal_tickets.create!(date: Date.today, bought: true)

    assert_equal @user, ticket.user
    assert_includes @user.meal_tickets, ticket
  end

  test "has_many meal_details association" do
    @user.save!
    detail = @user.meal_details.create!(
      date: Date.today,
      period: "Lunch",
      soup: "Soup"
    )

    assert_equal @user, detail.user
    assert_includes @user.meal_details, detail
  end

  test "has_many saldo_records association" do
    @user.save!
    record = @user.saldo_records.create!(cents: 1000)

    assert_equal @user, record.user
    assert_includes @user.saldo_records, record
  end

  test "has_many notifications association" do
    @user.save!
    notification = @user.notifications.create!(title: "Test", body: "Body")

    assert_equal @user, notification.user
    assert_includes @user.notifications, notification
  end

  test "destroy cascades to meal_tickets" do
    @user.save!
    @user.meal_tickets.create!(date: Date.today, bought: true)

    assert_difference "MealTicket.count", -1 do
      @user.destroy
    end
  end

  test "destroy cascades to meal_details" do
    @user.save!
    @user.meal_details.create!(date: Date.today, period: "Lunch", soup: "Soup")

    assert_difference "MealDetail.count", -1 do
      @user.destroy
    end
  end

  test "destroy cascades to saldo_records" do
    @user.save!
    @user.saldo_records.create!(cents: 1000)

    assert_difference "SaldoRecord.count", -1 do
      @user.destroy
    end
  end

  test "destroy cascades to notifications" do
    @user.save!
    @user.notifications.create!(title: "Test", body: "Body")

    assert_difference "Notification.count", -1 do
      @user.destroy
    end
  end
end
