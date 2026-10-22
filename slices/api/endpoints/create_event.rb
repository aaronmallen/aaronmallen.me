# frozen_string_literal: true

module API
  module Endpoints
    class CreateEvent < CalendarEventEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          calendar_id: Helpers::Schema::ID.merge(description: "the calendar's ID, from an event list_calendar lists"),
          **FIELDS,
        },
        required: %w[calendar_id title date],
      }.freeze

      REPLY = Helpers::Schema.object(
        { calendar_id: Helpers::Schema::INTEGER, created: Helpers::Schema::BOOLEAN },
      ).freeze

      include Deps[create_event: "calendar.operations.create_event"]

      def handle(calendar_id:, all_day: false, starts: nil, ends: nil, place: nil, **fields)
        result = create_event.call(calendar_id, { **fields, all_day:, starts:, ends:, place: })

        written(result, calendar_id, field: :calendar_id, noun: "calendar") { Success(calendar_id:, created: true) }
      end
    end
  end
end
