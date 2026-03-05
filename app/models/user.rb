# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :meal_tickets, dependent: :destroy
  has_many :meal_details, dependent: :destroy
  has_many :saldo_records, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  encrypts :giae_username, :giae_password, :giae_school_code

  # Default school code for GIAE
  # until we know how to get a list of schools let's keep it hardcoded
  DEFAULT_SCHOOL_CODE = "161676"

  # Remember me token expiration (2 weeks)
  REMEMBER_EXPIRATION = 2.weeks

  before_validation :set_default_school_code, on: :create

  after_create_commit :enqueue_initial_data_fetch

  # Generate a new remember token and save it
  def remember_me!
    update!(
      remember_token: SecureRandom.urlsafe_base64(32),
      remember_created_at: Time.current
    )
    remember_token
  end

  # Clear remember token
  def forget_me!
    update!(
      remember_token: nil,
      remember_created_at: nil
    )
  end

  # Check if remember token is valid (not expired)
  def remember_token_valid?(token)
    return false if remember_token.nil? || remember_created_at.nil?
    return false if remember_token != token
    return false if remember_created_at < REMEMBER_EXPIRATION.ago

    true
  end

  def meal_tickets_for_month(month, year)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    meal_tickets.where(date: start_date..end_date).order(:date)
  end

  def current_month_tickets
    now = Date.today
    meal_tickets_for_month(now.month, now.year)
  end

  def unread_notifications
    notifications.unread.chronological
  end

  def unread_notification_count
    notifications.unread.count
  end

  # Check if a refresh is currently in progress for this user
  def refresh_in_progress?
    Rails.cache.exist?("refresh_meal_tickets_#{id}") ||
      Rails.cache.exist?("fetch_saldo_#{id}")
  end

  private

  def set_default_school_code
    self.giae_school_code ||= DEFAULT_SCHOOL_CODE
  end

  def enqueue_initial_data_fetch
    RefreshMealTicketsJob.perform_later(id)
    FetchSaldoDisponivelJob.perform_later(id)
  end
end
