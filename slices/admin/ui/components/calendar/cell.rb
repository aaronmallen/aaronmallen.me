# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Cell < Component
          prop :day, Blog::Types::Instance(API::Queries::Calendar::Day)
          prop :month, Blog::Types::Date
          prop :picked, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            li(class: ["cal-day", ("cal-out" unless inside?), ("cal-today" if today?), ("cal-picked" if picked?)]) do
              a(class: "cal-link", href: path(:admin_calendar, day: date.iso8601), **link_attributes) do
                heading
                marks
              end
            end
          end

          private

          def date = @day.date

          def heading
            time(class: "cal-date", datetime: date.iso8601) do
              span(class: "sr-only") { l(date, format: :full) }
              span(class: "cal-day-name", aria: { hidden: "true" }) { l(date, format: :day_name) }
              span(class: "cal-num", aria: { hidden: "true" }) { date.day.to_s }
            end
          end

          def inside? = date.month == @month.month

          def link_attributes
            { aria: { current: ("date" if today?) }, data: { calendar_day: date.iso8601, calendar_past: past? } }
          end

          def mark(icon, text, kind)
            span(class: ["cal-mark", kind]) do
              i(class: icon, aria: { hidden: "true" })
              span(class: "cal-mark-text") { text }
            end
          end

          def marks
            span(class: "cal-marks") do
              sprint_mark
              @day.posts.each { mark("fa-solid fa-file-lines", it.title, "post") }
              social_mark
              mark("fa-solid fa-feather", t(".journal"), "journal") if @day.journal
            end
          end

          def past? = date < @today

          def picked? = date == @picked

          def social_mark
            count = @day.social_posts.size

            mark("fa-solid fa-paper-plane", t(".social", count:), "social") if count.positive?
          end

          def sprint_mark
            sprint = @day.sprint

            mark("fa-solid fa-list-check", t(".tasks", count: sprint.task_count), "sprint") if sprint
          end

          def today? = date == @today
        end
      end
    end
  end
end
