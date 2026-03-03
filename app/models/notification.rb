# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  enum :notification_type, { in_app: 0, email: 1 }, default: :in_app

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :chronological, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update(read_at: Time.current)
  end
end
