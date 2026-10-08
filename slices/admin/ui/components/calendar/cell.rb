# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Cell < Component
          SHOWN = 2

          prop :day, Blog::Types::Instance(API::Repos::CalendarQueries::Day)
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
              span(aria: { hidden: "true" }) { date.day.to_s }
            end
          end

          def inside? = date.month == @month.month

          def link_attributes
            { aria: { current: ("date" if today?) }, data: { calendar_day: date.iso8601, calendar_past: past? } }
          end

          def mark(icon, kind, &)
            span(class: ["cal-mark", kind]) do
              Icon(icon)
              span(class: "cal-mark-text", &)
            end
          end

          def marks
            span(class: "cal-marks") do
              @day.posts.each { |post| mark("fa-solid fa-file-lines", "post") { post.title } }
              social_marks
              sprint_mark
              mark("fa-solid fa-feather", "journal") { t(".journal") } if @day.journal
            end
          end

          def past? = date < @today

          def picked? = date == @picked

          def social_marks
            rest = @day.social_posts.size - SHOWN

            @day.social_posts.first(SHOWN).each do |post|
              mark("fa-solid fa-paper-plane", "social") do
                social_text(post)
              end
            end
            span(class: "cal-mark more") { t(".more_social", count: rest) } if rest.positive?
          end

          def social_text(social_post)
            at = l(Blog::TimeZone.local(social_post.posted_at), format: :clock)

            "#{at} #{Blog::Helpers::Truncation.cut(social_post.parts.first&.body.to_s, keep: Panel::TEXT_LIMIT)}"
          end

          def sprint_mark
            sprint = @day.sprint

            mark("fa-solid fa-list-check", "sprint") { t(".tasks", count: sprint.task_count) } if sprint
          end

          def today? = date == @today
        end
      end
    end
  end
end
