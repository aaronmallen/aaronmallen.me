# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Cell < Component
          SHOWN = 2

          prop :day, Blog::Types::Instance(::Calendar::Structs::CalendarDay)
          prop :month, Blog::Types::Date
          prop :picked, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :tones, Blog::Types::Hash

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

          def event_mark(event)
            span(class: ["cal-mark", "event", ("all-day" if event.all_day?)], style: tone(event)) do
              unless event.all_day?
                span(class: "cal-mark-time") { l(Blog::TimeZone.local(event.starts_at), format: :clock) }
              end
              span(class: "cal-mark-text") { event.title || t(".untitled") }
            end
          end

          def event_marks
            rest = @day.events.size - SHOWN

            @day.events.first(SHOWN).each { event_mark(it) }
            span(class: "cal-mark more") { t(".more_events", count: rest) } if rest.positive?
          end

          def heading
            Moment(at: date, class: "cal-date") do
              span(class: "sr-only") { l(date, format: :full) }
              span(class: "cal-day-name", aria: { hidden: "true" }) { l(date, format: :day_name) }
              span(aria: { hidden: "true" }) { date.day.to_s }
            end
          end

          def icon(kind) = ["fa-solid", Blog::Helpers::RecordKinds.icon(kind)]

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
              event_marks
              @day.posts.each { |post| mark(icon("post"), "post") { post.title } }
              social_marks
              sprint_mark
              mark(icon("journal_entry"), "journal") { t(".journal") } if @day.journal
            end
          end

          def past? = date < @today

          def picked? = date == @picked

          def social_marks
            rest = @day.social_posts.size - SHOWN

            @day.social_posts.first(SHOWN).each do |post|
              mark(icon("social_post"), "social") do
                social_text(post)
              end
            end
            span(class: "cal-mark more") { t(".more_social", count: rest) } if rest.positive?
          end

          def social_text(social_post)
            at = l(Blog::TimeZone.local(social_post.posted_at), format: :clock)

            "#{at} #{Helpers::Short.title(social_post.parts.first&.body.to_s)}"
          end

          def sprint_mark
            sprint = @day.sprint

            mark(icon("task"), "sprint") { t(".tasks", count: sprint.task_count) } if sprint
          end

          def today? = date == @today

          def tone(event) = Tone.style(@tones.fetch(event.calendar_id))
        end
      end
    end
  end
end
