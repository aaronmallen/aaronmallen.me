# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      STATUSES = Blog::Types::TaskStatus.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::WINDOW,
          page: Blog::Paging::PAGE,
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
        },
      }.freeze

      REPLY = Schema.object(
        { count: Schema::INTEGER, tasks: Schema.list(Serializers::Task.reference), partial: Schema::BOOLEAN },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", find_tasks: "tasks.queries.find_tasks"]

      def handle(from: nil, page: 1, statuses: nil, to: nil)
        case Blog::DayWindow.open_days(from, to)
        in Success[first, last] then Success(listed(Array(statuses), first, last, page))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(statuses, from, to, number)
        found = find_tasks.call(statuses:, from:, to:, page: Blog::Page.new(number:, size: settings.page_size[:mcp]))

        { count: found.rows.length, tasks: serialized(Serializers::Task, found.rows), **Blog::Paging.fields(found) }
      end
    end
  end
end
