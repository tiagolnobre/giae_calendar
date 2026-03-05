class MealDetail < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :period, presence: true
  validates :date, uniqueness: { scope: [ :user_id, :period ] }
end
