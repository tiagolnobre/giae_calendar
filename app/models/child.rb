class Child < ApplicationRecord
  belongs_to :user

  encrypts :giae_username, :giae_password, :giae_school_code

  DEFAULT_SCHOOL_CODE = "161676"

  before_validation :set_default_school_code, on: :create

  after_create_commit :enqueue_initial_data_fetch

  validates :giae_username, presence: true

  def meal_tickets_for_month(month, year)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    meal_tickets.where(date: start_date..end_date).order(:date)
  end

  def current_month_tickets
    now = Date.today
    meal_tickets_for_month(now.month, now.year)
  end

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
