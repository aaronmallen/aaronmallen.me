# frozen_string_literal: true

module Calendar
  module Operations
    class CreateEvent < Blog::Operation
      include EventWrites
      include Deps[
        calendar_queries: "repos.calendar_queries",
        contract: "contracts.event_contract",
        google: "google.client",
        honeybadger: "honeybadger.agent",
      ]

      def call(calendar_id, params)
        calendar = step writable(calendar_queries.calendar(calendar_id))
        fields = step validate(params)

        step(written(calendar) do
          body = GoogleEvent.body(fields, date: fields[:date])
          google.post(GoogleEvent.url(calendar), body, account: calendar.account)
        end)
      end
    end
  end
end
