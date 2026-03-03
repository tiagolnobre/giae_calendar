# frozen_string_literal: true

class MealTicket < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :date, uniqueness: { scope: :user_id }
  validates :bought, inclusion: { in: [ true, false ] }
  validates :dish_type, inclusion: { in: [ "meat", "fish", nil ] }

  scope :bought_tickets, -> { where(bought: true) }
  scope :not_bought_tickets, -> { where(bought: false) }

  def dish_type_icon
    case dish_type
    when "meat" then "🥩"
    when "fish" then "🐟"
    end
  end
end
