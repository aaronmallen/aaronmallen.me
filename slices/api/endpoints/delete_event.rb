# frozen_string_literal: true

module API
  module Endpoints
    class DeleteEvent < CalendarEventEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: ID, scope: SCOPE },
        required: %w[id],
      }.freeze

      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_event: "calendar.operations.delete_event"]

      def handle(id:, scope: nil)
        written(delete_event.call(id, scope:), id) { Success(id:, deleted: true) }
      end
    end
  end
end
