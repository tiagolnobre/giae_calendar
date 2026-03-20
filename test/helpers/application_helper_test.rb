# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "day_classes returns correct classes for today" do
    day = {
      date: Date.today,
      is_current_month: true,
      is_weekend: false,
      is_holiday: false
    }

    classes = day_classes(day)

    assert classes.include?("aspect-square")
    assert classes.include?("bg-white")
  end

  test "day_classes returns gray background for weekend days in current month" do
    day = {
      date: Date.today,
      is_current_month: true,
      is_weekend: true,
      is_holiday: false
    }

    classes = day_classes(day)

    assert classes.include?("bg-gray-100")
  end

  test "day_classes returns gray background for holidays in current month" do
    day = {
      date: Date.today,
      is_current_month: true,
      is_weekend: false,
      is_holiday: true
    }

    classes = day_classes(day)

    assert classes.include?("bg-gray-100")
  end

  test "day_classes returns gray-50 for days outside current month" do
    day = {
      date: Date.today,
      is_current_month: false,
      is_weekend: false,
      is_holiday: false
    }

    classes = day_classes(day)

    assert classes.include?("bg-gray-50")
  end

  test "day_style returns background color for today" do
    day = {
      date: Date.today,
      is_current_month: true
    }

    style = day_style(day)

    assert_equal "background-color: #FFF2D0;", style
  end

  test "day_style returns nil for days that are not today" do
    day = {
      date: Date.today - 1.day,
      is_current_month: true
    }

    style = day_style(day)

    assert_nil style
  end

  test "tooltip_attributes returns basic tooltip for non-current month days" do
    day = {
      date: Date.today,
      is_current_month: false,
      is_weekend: false,
      is_holiday: false
    }

    tooltip = tooltip_attributes(day)

    assert tooltip.include?(I18n.l(day[:date], format: :long))
    assert tooltip.include?("title=")
  end

  test "tooltip_attributes returns ticket status for current month days with ticket" do
    ticket = meal_tickets(:one)
    day = {
      date: ticket.date,
      is_current_month: true,
      is_weekend: false,
      is_holiday: false,
      ticket: ticket
    }

    tooltip = tooltip_attributes(day)

    assert tooltip.include?(I18n.l(day[:date], format: :long))
    assert tooltip.include?(ticket.bought ? "Comprado" : "Não comprado")
  end

  test "tooltip_attributes returns no info message for current month days without ticket" do
    day = {
      date: Date.today,
      is_current_month: true,
      is_weekend: false,
      is_holiday: false,
      ticket: nil
    }

    tooltip = tooltip_attributes(day)

    assert tooltip.include?(I18n.l(day[:date], format: :long))
    assert tooltip.include?("Sem informação")
  end
end
