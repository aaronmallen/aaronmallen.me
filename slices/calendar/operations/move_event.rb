# frozen_string_literal: true

module Calendar
  module Operations
    class MoveEvent < Blog::Operation
      include EventWrites
      include Deps[
        calendar_mutations: "repos.calendar_mutations", calendar_queries: "repos.calendar_queries",
        google: "google.client",
      ]

      def call(id, date, now: Time.now)
        day = step upcoming_day(date, now)
        event = step found(calendar_queries.event(id))
        calendar = step writable(event.calendar)

        step(written(calendar) { change(calendar, event, moved(event, day - event.starts_on)) })
        day
      end

      private

      def body(times)
        return { start: GoogleEvent.whole(times[:starts_on]), end: GoogleEvent.whole(times[:ends_on] + 1) } unless
          times[:starts_at]

        { start: instant(times[:starts_at]), end: instant(times[:ends_at]) }
      end

      def change(calendar, event, times)
        google.patch(GoogleEvent.url(calendar, event.google_id), body(times), account: calendar.account)
        calendar_mutations.move_event(event.id, times)
      end

      def instant(time) = { date: nil, dateTime: time.iso8601, timeZone: Blog::TimeZone::NAME }

      def moved(event, days)
        dates = { starts_on: event.starts_on + days, ends_on: event.ends_on + days }
        return dates if event.all_day?

        { **dates, starts_at: shifted(event.starts_at, days), ends_at: shifted(event.ends_at, days) }
      end

      def shifted(time, days) = Blog::TimeZone.on_day(time, Blog::TimeZone.today(time) + days)
    end
  end
end
