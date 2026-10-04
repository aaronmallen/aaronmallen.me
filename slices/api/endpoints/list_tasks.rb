# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      LISTS = Blog::Types::TaskList.values.freeze
      OPEN = [Blog::Types::TaskStatus["open"], Blog::Types::TaskStatus["in_progress"]].freeze
      STATUSES = Blog::Types::TaskStatus.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::WINDOW,
          lists: {
            type: "array",
            items: { type: "string", enum: LISTS },
            description: "next, someday or external; open tasks unless you name statuses; every list when left out",
          },
          page: Blog::Paging::PAGE,
          query: { type: "string", description: "words to find in the title or note" },
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
          tag: { type: "string", description: "a tag the task carries; any tag when you leave it out" },
        },
      }.freeze

      REPLY = Schema.object(
        { count: Schema::INTEGER, tasks: Schema.list(Serializers::Task.reference), partial: Schema::BOOLEAN },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", find_tasks: "tasks.queries.find_tasks"]

      def handle(from: nil, page: 1, to: nil, **filters)
        case Blog::DayWindow.open_days(from, to)
        in Success[first, last] then Success(listed(narrowed(**filters), first, last, page))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(filters, from, to, number)
        found = find_tasks.call(**filters, from:, to:, page: Blog::Page.new(number:, size: settings.page_size[:mcp]))

        { count: found.rows.length, tasks: serialized(Serializers::Task, found.rows), **Blog::Paging.fields(found) }
      end

      def narrowed(lists: [], query: nil, statuses: [], tag: nil)
        named = statuses.empty? && lists.any? ? OPEN : statuses

        { lists:, statuses: named, tags: [tag.to_s.strip.downcase].reject(&:empty?), text: query.to_s.strip }
      end
    end
  end
end
