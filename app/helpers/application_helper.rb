# frozen_string_literal: true

module ApplicationHelper
  def day_classes(day)
    classes = [ "aspect-square p-1 flex items-center justify-center" ]

    classes << if day[:is_current_month]
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
