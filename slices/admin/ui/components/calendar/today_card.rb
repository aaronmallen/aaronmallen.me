# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class TodayCard < Component
          HOUR = 60
          SOON = 180

          prop :events, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tomorrow, Blog::Types::Instance(ROM::Struct).optional
          prop :tones, Blog::Types::Hash
          prop :writable, Blog::Types::Bool
          prop :now, Blog::Types::Time

          def view_template
            Card(title: t(".title"), data:) do |card|
              card.side { side }
              rows
            end
          end

          private

          def all_day = @all_day ||= @events.select(&:all_day?)

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def data
            {
              today_calendar: "", left: t(".left", left: "{left}", total: "{total}"),
              soon_minutes: t(".soon.minutes", minutes: "{m}"), soon_hours: t(".soon.hours", hours: "{h}"),
              soon_both: t(".soon.both", hours: "{h}", minutes: "{m}"),
            }
          end

          def done
            p(class: "today-para") do
              plain t(".done")
              next unless @tomorrow

              whitespace
              plain t(".first_tomorrow")
              whitespace
              b { @tomorrow.title || t(".untitled") }
              whitespace
              plain t(".at", time: clock(@tomorrow.starts_at))
            end
          end

          def earlier
            details(class: "today-more") do
              summary do
                Icon("fa-solid fa-chevron-right today-more-chev")
                plain t(".earlier", count: past.size)
              end
              past.each { row(it, state: "past") }
            end
          end

          def ended?(event) = event.ends_at <= @now

          def left = @left ||= timed.reject { ended?(it) }

          def new_event
            return unless @writable

            day = Blog::TimeZone.local_date(@now).iso8601

            Button(href: path(:admin_calendar, day:), icon: :add, label: t(".new_event"))
          end

          def past = @past ||= timed.select { ended?(it) }

          def row(event, **) = TodayEvent(event:, tone: @tones.fetch(event.calendar_id), soon: soon(event), **)

          def rows
            all_day.each { row(it) }
            left.each { row(it, state: state(it)) }
            return Empty { t(".empty") } if @events.empty?

            done if left.empty? && all_day.empty?
            earlier if past.any?
          end

          def side
            span(class: "card-note", data: { today_calendar_left: "" }) { tally }
            span(class: "card-note", aria: { hidden: "true" }) { DOT.strip }
            a(class: "today-link", href: path(:admin_calendar)) { t(".week") }
            new_event
          end

          def soon(event)
            return unless event == upcoming

            minutes = ((event.starts_at - @now) / 60).ceil
            return t(".soon.minutes", minutes:) if minutes < HOUR
            return unless minutes < SOON

            hours, minutes = minutes.divmod(HOUR)
            minutes.zero? ? t(".soon.hours", hours:) : t(".soon.both", hours:, minutes:)
          end

          def state(event)
            return "now" if event.starts_at <= @now

            "next" if event == upcoming
          end

          def tally = timed.empty? ? t(".clear") : t(".left", left: left.size, total: timed.size)

          def timed = @timed ||= @events.reject(&:all_day?)

          def upcoming = @upcoming ||= left.find { it.starts_at > @now }
        end
      end
    end
  end
end
