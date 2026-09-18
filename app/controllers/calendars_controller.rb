# frozen_string_literal: true

class CalendarsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_child!

  def show
    @child = current_child
    @month = (params[:month].to_i > 0) ? params[:month].to_i : Date.today.month
    @year = (params[:year].to_i > 0) ? params[:year].to_i : Date.today.year

    # Validate month and year are reasonable
    unless @month.between?(1, 12) && @year.between?(2000, 2100)
      redirect_to calendar_path and return
    end

    @tickets = @child.meal_tickets_for_month(@month, @year)
    @tickets_by_date = @tickets.index_by(&:date)

    @calendar_days = build_calendar_days

    @today_details = @child.meal_details.where(date: Date.today).order(:period)
  end

  def refresh
    @child = current_child

    if @child.refresh_in_progress?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "refresh-status",
            partial: "refresh_status",
            locals: { child: @child, refreshing: true, message: "Refresh already in progress..." }
          )
        end
        format.html { redirect_to calendar_path, alert: "A refresh is already in progress. Please wait." }
      end
      return
    end

    RefreshMealTicketsJob.perform_later(@child.id)
    FetchSaldoDisponivelJob.perform_later(@child.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "refresh-status",
          partial: "refresh_status",
          locals: { child: @child, refreshing: true, message: "Refreshing meal tickets..." }
        )
      end
      format.html { redirect_to calendar_path, notice: "Refreshing meal tickets..." }
    end
  end

  def day_details
    @child = current_child
    @date = begin
      Date.parse(params[:date])
    rescue
      Date.today
    end

    @meal_details = @child.meal_details.where(date: @date).order(:period)
    @meal_ticket = @child.meal_tickets.find_by(date: @date)

    render partial: "calendars/day_modal", layout: false, locals: { date: @date, meal_details: @meal_details, meal_ticket: @meal_ticket }
  end

  private

  def require_child!
    unless current_child
      redirect_to children_path, alert: t("children.need_one") and return
    end
  end

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

  def history
    @child = current_child
    @months = []

    start_date = Date.today.beginning_of_month
    end_date = start_date - 12.months

    current = end_date
    while current <= start_date
      tickets = @child.meal_tickets.where("date >= ? AND date < ?", current.beginning_of_month, current.end_of_month + 1.day)
      bought_count = tickets.where(bought: true).count
      total_days = tickets.count

      @months << {
        month: current.month,
        year: current.year,
        month_name: I18n.t("date.month_names")[current.month],
        bought_count: bought_count,
        total_days: total_days
      }

      current += 1.month
    end
  end
end