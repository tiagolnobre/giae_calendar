# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :meal_tickets, dependent: :destroy
  has_many :saldo_records, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  encrypts :giae_username, :giae_password

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
end
