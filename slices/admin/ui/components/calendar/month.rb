# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Month < Component
          prop :days, Blog::Types::Array.of(Blog::Types::Instance(API::Queries::Calendar::Day))
          prop :month, Blog::Types::Date
          prop :picked, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            div(class: "cal-month") do
              div(class: "cal-weekdays", aria: { hidden: "true" }) do
                @days.first(Operations::BuildCalendarPage::WEEK).each do |day|
                  span(class: "cal-weekday") { l(day.date, format: :day_name) }
                end
              end
              ol(class: "cal-days", aria: { label: l(@month, format: :month) }) do
                @days.each { Cell(day: it, month: @month, today: @today, picked: @picked) }
              end
            end
          end
        end
      end
    end
  end
end
