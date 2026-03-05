require "test_helper"

class SaldoRecordTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @saldo_record = SaldoRecord.new(
      user: @user,
      cents: 1500
    )
  end

  test "should be valid with all required attributes" do
    assert @saldo_record.valid?
  end

  test "should belong to user" do
    assert_equal @user, @saldo_record.user
  end

  test "cents should be present" do
    @saldo_record.cents = nil
    assert_not @saldo_record.valid?
    assert @saldo_record.errors[:cents].any?
  end

  test "cents should be an integer" do
    @saldo_record.cents = 15.50
    assert_not @saldo_record.valid?
    assert @saldo_record.errors[:cents].any?
  end

  test "cents should be greater than or equal to 0" do
    @saldo_record.cents = -100
    assert_not @saldo_record.valid?
    assert @saldo_record.errors[:cents].any?
  end

  test "cents of 0 should be valid" do
    @saldo_record.cents = 0
    assert @saldo_record.valid?
  end

  test "latest scope should return records in descending order" do
    @user.saldo_records.create!(cents: 1000)
    sleep 0.01
    @user.saldo_records.create!(cents: 2000)
    sleep 0.01
    @user.saldo_records.create!(cents: 3000)

    records = @user.saldo_records.latest.to_a
    assert_equal [ 3000, 2000, 1000 ], records.map(&:cents)
  end

  test "for_user scope should filter by user" do
    @saldo_record.save!

    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "otheruser",
      giae_password: "otherpass"
    )
    other_record = other_user.saldo_records.create!(cents: 500)

    assert_includes SaldoRecord.for_user(@user), @saldo_record
    assert_not_includes SaldoRecord.for_user(@user), other_record
  end

  test "latest_for_user should return most recent record for user" do
    @user.saldo_records.create!(cents: 1000, created_at: 1.day.ago)
    latest = @user.saldo_records.create!(cents: 2500, created_at: Time.current)

    assert_equal latest, SaldoRecord.latest_for_user(@user)
  end

  test "latest_for_user should return nil when no records exist" do
    new_user = User.create!(
      email: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      giae_username: "newuser",
      giae_password: "newpass"
    )
    assert_nil SaldoRecord.latest_for_user(new_user)
  end
end
