# frozen_string_literal: true

module API
  module Endpoints
    class ListSprints < Endpoint
      BAD_DAY = "give from and to as days, such as 2026-01-01"
      BAD_WINDOW = "from comes after to"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          page: Blog::Paging::PAGE,
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
      }.freeze

      include Deps["settings", sprints_between: "tasks.queries.sprints_between"]

      def handle(from: nil, to: nil, page: 1)
        case window(from || opening(to), to)
        in Success[first, last] then Success(listed(first, last, Blog::Page.new(number: page, size:)))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def day(value) = value && Blog::TimeZone.parse_day(value)

      def listed(first, last, page)
        found = sprints_between.call(from: first, to: last, page:)

        { sprints: serialized(Serializers::Sprint, found.rows), **Blog::Paging.fields(found) }
      end

      def opening(to) = to ? nil : Blog::TimeZone.today.iso8601

      def size = settings.page_size[:mcp]

      def unread?(value, parsed) = !value.nil? && parsed.nil?

      def window(from, to)
        first, last = [from, to].map { day(it) }
        return Failure(BAD_DAY) if unread?(from, first) || unread?(to, last)
        return Failure(BAD_WINDOW) if first && last && first > last

        Success([first, last])
      end
    end
  end
end
