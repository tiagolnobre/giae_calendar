# frozen_string_literal: true

module ApplicationHelper
  def grade_color(grade)
    case grade.to_s.strip.upcase
    when "MB"
      "bg-green-100 text-green-800"
    when "B"
      "bg-blue-100 text-blue-800"
    when "S"
      "bg-yellow-100 text-yellow-800"
    when "I"
      "bg-red-100 text-red-800"
    when "NS"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
  def day_classes(day)
    classes = [ "aspect-square p-1 flex items-center justify-center" ]

    classes << if day[:date] == Date.today
      "bg-white"
    elsif day[:is_current_month]
      if day[:is_weekend] || day[:is_holiday]
        "bg-gray-100"
      else
        "bg-white"
      end
    else
      "bg-gray-50"
    end

    classes.join(" ")
  end

  def day_style(day)
    "background-color: #FFF2D0;" if day[:date] == Date.today
  end

  def tooltip_attributes(day)
    return "title=\"#{l(day[:date], format: :long)}\"".html_safe unless day[:is_current_month] && !day[:is_weekend] && !day[:is_holiday]

    if day[:ticket]
      status = day[:ticket].bought ? "Comprado" : "Não comprado"
      "title=\"#{l(day[:date], format: :long)}: #{status}\"".html_safe
    else
      "title=\"#{l(day[:date], format: :long)}: Sem informação\"".html_safe
    end
  end
end
