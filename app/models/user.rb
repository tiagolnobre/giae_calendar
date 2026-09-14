# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :meal_tickets, dependent: :destroy
  has_many :meal_details, dependent: :destroy
  has_many :saldo_records, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :school_years, dependent: :destroy
  has_many :children, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  # Remember me token expiration (2 weeks)
  REMEMBER_EXPIRATION = 2.weeks

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

  def unread_notifications
    notifications.unread.chronological
  end

  def unread_notification_count
    notifications.unread.count
  end
end