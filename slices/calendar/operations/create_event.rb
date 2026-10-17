# frozen_string_literal: true

module Calendar
  module Operations
    class CreateEvent < EventOperation
      include Deps[calendar_queries: "repos.calendar_queries", contract: "contracts.event_contract"]

      def call(calendar_id, params)
        calendar = step writable(calendar_queries.calendar(calendar_id))
        fields = step validate(params)

        step(written(calendar) do
          body = Helpers::GoogleEvent.body(fields, date: fields[:date])
          google.post(Helpers::GoogleEvent.url(calendar), body, account: calendar.account)
        end)
      end
    end
  end
end
