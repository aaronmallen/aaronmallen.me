# frozen_string_literal: true

module API
  module Endpoints
    class ListWorkEntries < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: Helpers::DayWindow::RANGE,
        required: %w[from to],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          work_entries: Helpers::Schema.list(Serializers::WorkEntry.reference),
        },
      ).freeze

      include Deps[work_entry_queries: "projects.repos.work_entry_queries"]

      def handle(from:, to:)
        case Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last)
        entries = work_entry_queries.between(from: first, to: last)

        { from: first.iso8601, to: last.iso8601, work_entries: serialized(Serializers::WorkEntry, entries) }
      end
    end
  end
end
