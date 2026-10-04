# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Calendar
        class Show < View
          include Components::Calendar

          def initialize(month:, today:, days:, day:, tasks:)
            super()
            @month = month
            @today = today
            @days = days
            @day = day
            @tasks = tasks
          end

          def view_template
            PageHead(title: t(".heading"), sub: l(@month, format: :month)) do
              MonthPager(month: @month, today: @today)
            end

            div(class: "cal", data: { calendar: "" }) do
              Month(month: @month, today: @today, days: @days, picked: @day.date)
              Panel(day: @day, tasks: @tasks, today: @today)
            end
          end
        end
      end
    end
  end
end
