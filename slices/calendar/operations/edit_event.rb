# frozen_string_literal: true

module Calendar
  module Operations
    class EditEvent < Blog::Operation
      include EventWrites
      include Deps[
        calendar_queries: "repos.calendar_queries",
        contract: "contracts.event_contract",
        google: "google.client",
      ]

      def call(id, params, scope: nil)
        event = step found(calendar_queries.event(id))
        calendar = step writable(event.calendar)
        fields = step validate(params, event)

        step(written(calendar) { change(calendar, event, fields, series(event, scope)) })
      end

      private

      def change(calendar, event, fields, series)
        target, date = series ? [series, shifted(calendar, event, fields)] : [event.google_id, fields[:date]]
        span = span(event)

        google.patch(
          GoogleEvent.url(calendar, target), GoogleEvent.body(fields, date:, span:), account: calendar.account,
        )
      end

      def shifted(calendar, event, fields)
        series = google.get(GoogleEvent.url(calendar, event.recurring_id), account: calendar.account)

        GoogleEvent.first_day(series) + (fields[:date] - event.starts_on)
      end

      def span(event)
        return event.ends_on - event.starts_on if event.all_day?

        Blog::TimeZone.today(event.ends_at) - Blog::TimeZone.today(event.starts_at)
      end

      def validate(params, event) = validated(contract.call(every_field(params), span: span(event)))
    end
  end
end
