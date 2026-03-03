# frozen_string_literal: true

class SaldoRecord < ApplicationRecord
  belongs_to :user

  validates :cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :latest, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  def self.latest_for_user(user)
    for_user(user).latest.first
  end
end
