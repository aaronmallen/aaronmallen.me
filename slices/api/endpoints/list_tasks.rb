# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      BAD_DAY = "give from and to as days, such as 2026-01-01"
      BAD_WINDOW = "from comes after to"
      STATUSES = Blog::Types::TaskStatus.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          page: Blog::Paging::PAGE,
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
      }.freeze

      include Deps["settings", find_tasks: "tasks.queries.find_tasks"]

      def handle(from: nil, page: 1, statuses: nil, to: nil)
        case window(from, to)
        in Success[first, last] then Success(listed(Array(statuses), first, last, page))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def day(value) = value && Blog::TimeZone.parse_day(value)

      def listed(statuses, from, to, number)
        found = find_tasks.call(statuses:, from:, to:, page: Blog::Page.new(number:, size: settings.page_size[:mcp]))

        { count: found.rows.length, tasks: serialized(Serializers::Task, found.rows), **Blog::Paging.fields(found) }
      end

      def unread?(value, day) = !value.nil? && day.nil?

      def window(from, to)
        first, last = [from, to].map { day(it) }
        return Failure(BAD_DAY) if unread?(from, first) || unread?(to, last)
        return Failure(BAD_WINDOW) if first && last && first > last

        Success([first, last])
      end
    end
  end
end
