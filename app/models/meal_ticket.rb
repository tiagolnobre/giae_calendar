# frozen_string_literal: true

class MealTicket < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :date, uniqueness: { scope: :user_id }
  validates :bought, inclusion: { in: [ true, false ] }

  scope :bought_tickets, -> { where(bought: true) }
  scope :not_bought_tickets, -> { where(bought: false) }
end
