# frozen_string_literal: true

module Calendar
  module Operations
    class DeleteEvent < EventOperation
      include Deps[calendar_queries: "repos.calendar_queries"]

      def call(id, scope: nil)
        event = step found(calendar_queries.event(id))
        calendar = step writable(event.calendar)
        target = series(event, scope) || event.google_id

        url = Helpers::GoogleEvent.url(google, calendar, target)

        step(written(calendar) { google.delete(url, account: calendar.account) })
      end
    end
  end
end
