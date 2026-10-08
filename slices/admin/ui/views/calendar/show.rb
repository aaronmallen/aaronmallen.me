# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Calendar
        class Show < View
          include Components::Calendar

          prop :month, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :days, Blog::Types::Array.of(Blog::Types::Instance(API::Repos::CalendarQueries::Day))
          prop :day, Blog::Types::Instance(API::Repos::CalendarQueries::Day)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            PageHead(title: t(".heading"), sub: l(@month, format: :month)) do
              MonthPager(month: @month, today: @today)
            end

            div(class: "g-main", data: { calendar: "" }) do
              section(class: "card") { Month(month: @month, today: @today, days: @days, picked: @day.date) }
              Panel(day: @day, tasks: @tasks, today: @today)
            end
          end
        end
      end
    end
  end
end
