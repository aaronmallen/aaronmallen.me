# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Calendar
        class Show < View
          include Components::Calendar

          prop :month, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :days, Blog::Types::Array.of(Blog::Types::Instance(API::Structs::CalendarDay))
          prop :day, Blog::Types::Instance(API::Structs::CalendarDay)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :calendars, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tones, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub: l(@month, format: :month)) do
              Picker(calendars: @calendars, tones: @tones, day: @day.date)
              MonthPager(month: @month, today: @today)
            end

            div(class: "g-main", data: { calendar: "" }) do
              section(class: "card") do
                Month(month: @month, today: @today, days: @days, picked: @day.date, tones: @tones)
              end
              Panel(day: @day, tasks: @tasks, today: @today, tones: @tones)
            end
          end
        end
      end
    end
  end
end
