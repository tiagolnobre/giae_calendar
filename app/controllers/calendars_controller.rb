# frozen_string_literal: true

class CalendarsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @month = (params[:month].to_i > 0) ? params[:month].to_i : Date.today.month
    @year = (params[:year].to_i > 0) ? params[:year].to_i : Date.today.year

    @tickets = @user.meal_tickets_for_month(@month, @year)
    @tickets_by_date = @tickets.index_by(&:date)

    @calendar_days = build_calendar_days
  end

  def refresh
    @user = current_user

    RefreshMealTicketsJob.perform_later(@user.id)
    FetchSaldoDisponivelJob.perform_later(@user.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "refresh-status",
          partial: "refresh_status",
          locals: { user: @user, refreshing: true }
        )
      end
      format.html { redirect_to calendar_path, notice: "Refreshing meal tickets..." }
    end
  end

  private

  def build_calendar_days
    first_day = Date.new(@year, @month, 1)
    last_day = first_day.end_of_month
    start_day = first_day.beginning_of_week(:monday)
    end_day = last_day.end_of_week(:monday)

    days = []
    current = start_day
    while current <= end_day
      days << {
        date: current,
        is_current_month: current.month == @month,
        is_weekend: current.saturday? || current.sunday?,
        is_holiday: portuguese_holiday?(current),
        ticket: @tickets_by_date[current]
      }
      current += 1
    end
    days
  end

  def portuguese_holiday?(date)
    Holidays.on(date, :pt).any?
  end
end
