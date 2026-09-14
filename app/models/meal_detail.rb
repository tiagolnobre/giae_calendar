class MealDetail < ApplicationRecord
  belongs_to :user
  belongs_to :child, optional: true

  before_validation :sync_user_id, on: :create

  validates :date, presence: true
  validates :period, presence: true
  validates :date, uniqueness: { scope: [ :child_id, :period ] }, if: -> { child_id.present? }

  private

  def sync_user_id
    self.user_id = child.user_id if child && child.user_id && user_id.nil?
  end
end