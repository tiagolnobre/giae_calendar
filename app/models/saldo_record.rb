# frozen_string_literal: true

class SaldoRecord < ApplicationRecord
  belongs_to :user
  belongs_to :child, optional: true

  before_validation :sync_user_id, on: :create

  validates :cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :latest, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_child, ->(child) { where(child_id: child.id) }

  def self.latest_for_user(user)
    for_user(user).latest.first
  end

  def self.latest_for_child(child)
    for_child(child).latest.first
  end

  private

  def sync_user_id
    self.user_id = child.user_id if child && child.user_id && user_id.nil?
  end
end