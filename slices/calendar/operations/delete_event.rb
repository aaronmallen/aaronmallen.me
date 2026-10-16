# frozen_string_literal: true

module Calendar
  module Operations
    class DeleteEvent < Blog::Operation
      include EventWrites
      include Deps[
        google: "google.client", calendar_queries: "repos.calendar_queries", honeybadger: "honeybadger.agent",
      ]

      def call(id, scope: nil)
        event = step found(calendar_queries.event(id))
        calendar = step writable(event.calendar)
        target = series(event, scope) || event.google_id

        step(written(calendar) { google.delete(GoogleEvent.url(calendar, target), account: calendar.account) })
      end
    end
  end
end
