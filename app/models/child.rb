# frozen_string_literal: true

class Child < ApplicationRecord
  belongs_to :user

  has_many :meal_tickets, dependent: :destroy
  has_many :meal_details, dependent: :destroy
  has_many :saldo_records, dependent: :destroy
  has_many :school_years, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one :giae_session, dependent: :destroy

  encrypts :giae_username, :giae_password, :giae_school_code

  # Default school code for GIAE
  # until we know how to get a list of schools let's keep it hardcoded
  DEFAULT_SCHOOL_CODE = "161676"

  before_validation :set_default_school_code, on: :create

  after_create_commit :enqueue_initial_data_fetch

  validates :giae_username, presence: true

  def display_name
    nome_utilizador.presence || giae_username.presence || "Child ##{id}"
  end

  def latest_saldo
    saldo_records.latest.first
  end

  def meal_tickets_for_month(month, year)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    meal_tickets.where(date: start_date..end_date).order(:date)
  end

  def current_month_tickets
    now = Date.today
    meal_tickets_for_month(now.month, now.year)
  end

  # Check if a refresh is currently in progress for this child
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