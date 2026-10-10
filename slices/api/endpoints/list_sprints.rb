# frozen_string_literal: true

module API
  module Endpoints
    class ListSprints < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::WINDOW,
          page: Blog::Helpers::Paging::PAGE,
        },
      }.freeze

      REPLY = Helpers::Schema.object(
        { sprints: Helpers::Schema.list(Serializers::Sprint.reference), partial: Helpers::Schema::BOOLEAN },
        optional: { next_page: Helpers::Schema::INTEGER },
      ).freeze

      include Deps["settings", sprint_queries: "tasks.repos.sprint_queries"]

      def handle(from: nil, to: nil, page: 1)
        case Blog::Helpers::DayWindow.open_days(from || opening(to), to)
          in Success[first, last] then Success(listed(first, last, page_of(page)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, page)
        found = sprint_queries.between(from: first, to: last, page:)

        { sprints: serialized(Serializers::Sprint, found.rows), **Blog::Helpers::Paging.fields(found) }
      end

      def opening(to) = to ? nil : Blog::TimeZone.today.iso8601
    end
  end
end
