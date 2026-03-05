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
end
