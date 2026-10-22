# frozen_string_literal: true

module API
  module Endpoints
    class MoveEvent < CalendarEventEndpoint
      NOT_A_DAY = "to needs a day, such as 2026-01-01"
      PAST = "to falls before today; pick today or a later day"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: ID,
          to: { **Helpers::Schema::DAY, description: "the day to move it to, as YYYY-MM-DD, today or later" },
          scope: SCOPE,
        },
        required: %w[id to],
      }.freeze

      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, date: Helpers::Schema::DAY }).freeze

      include Deps[edit_event: "calendar.operations.edit_event", move_event: "calendar.operations.move_event"]

      def handle(id:, to:, scope: nil)
        event = calendar_queries.event(id)
        return missing("event", id) if event.nil?
        return series(event, to) if event.recurring_id && scope == ::Calendar::EventOperation::SERIES

        moved(id, to)
      end

      private

      def moved(id, to)
        case move_event.call(id, to)
          in Success(day) then Success(id:, date: day.iso8601)
          in Failure(:past) then invalid(to: [PAST])
          in Failure(:invalid) then invalid(to: [NOT_A_DAY])
          in result then written(result, id) { Success(id:, date: to) }
        end
      end

      def series(event, to)
        result = edit_event.call(event.id, fields_of(event).merge(date: to), scope: ::Calendar::EventOperation::SERIES)

        written(result, event.id) { Success(id: event.id, date: to) }
      end
    end
  end
end
