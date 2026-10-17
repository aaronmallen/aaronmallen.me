# frozen_string_literal: true

module Calendar
  module Operations
    class EditEvent < EventOperation
      include Deps[
        calendar_queries: "repos.calendar_queries",
        contract: "contracts.event_contract",
        google: "google.client",
        honeybadger: "honeybadger.agent",
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
        body = Helpers::GoogleEvent.body(fields, date:, span: new_span(event, fields))

        google.patch(Helpers::GoogleEvent.url(calendar, target), body, account: calendar.account)
      end

      def clock(time) = Blog::TimeZone.local(time).strftime("%H:%M")

      def crossed(starts, ends) = ends <= starts ? 1 : 0

      def new_span(event, fields)
        return span(event) if event.all_day? && fields[:all_day]

        days = event.all_day? ? 0 : [span(event) - crossed(clock(event.starts_at), clock(event.ends_at)), 0].max
        fields[:all_day] ? days : days + crossed(fields[:starts], fields[:ends])
      end

      def shifted(calendar, event, fields)
        series = google.get(Helpers::GoogleEvent.url(calendar, event.recurring_id), account: calendar.account)

        Helpers::GoogleEvent.first_day(series) + (fields[:date] - event.starts_on)
      end

      def span(event)
        return event.ends_on - event.starts_on if event.all_day?

        Blog::TimeZone.today(event.ends_at) - Blog::TimeZone.today(event.starts_at)
      end

      def validate(params, event) = validated(contract.call(every_field(params), span: span(event)))
    end
  end
end
