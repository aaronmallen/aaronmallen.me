# frozen_string_literal: true

module API
  module Endpoints
    class EditEvent < CalendarEventEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: ID, **FIELDS, scope: SCOPE },
        required: %w[id],
      }.freeze

      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, saved: Helpers::Schema::BOOLEAN }).freeze

      include Deps[edit_event: "calendar.operations.edit_event"]

      def handle(id:, scope: nil, **fields)
        event = calendar_queries.event(id)
        return missing("event", id) if event.nil?

        result = edit_event.call(id, fields_of(event).merge(fields), scope:)
        written(result, id) { Success(id:, saved: true) }
      end
    end
  end
end
