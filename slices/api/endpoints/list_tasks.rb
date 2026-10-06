# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      BAD_SPRINT_DAY = "give sprint_on as a day, such as 2026-01-01"
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
          sprint_on: { type: "string", description: "a sprint day, as YYYY-MM-DD; only the tasks planned into it" },
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
          tag: { type: "string", description: "a tag the task carries; any tag when you leave it out" },
        },
      }.freeze

      REPLY = Schema.object(
        {
          count: Schema::INTEGER,
          total: Schema::INTEGER,
          tasks: Schema.list(Serializers::Task.reference),
          partial: Schema::BOOLEAN,
        },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", find_tasks: "tasks.queries.find_tasks"]

      def handle(from: nil, page: 1, sprint_on: nil, to: nil, **filters)
        day = sprint_on && Blog::TimeZone.parse_day(sprint_on)
        return invalid(sprint_on: [BAD_SPRINT_DAY]) if sprint_on && day.nil?

        case Blog::DayWindow.open_days(from, to)
        in Success[first, last] then Success(listed(narrowed(**filters, sprint_on: day), first, last, page))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(filters, from, to, number)
        found = find_tasks.call(**filters, from:, to:, page: page_of(number))
        rows = found.paged.rows

        {
          count: rows.length,
          total: found.total,
          tasks: serialized(Serializers::Task, rows),
          **Blog::Paging.fields(found.paged),
        }
      end

      def narrowed(lists: [], query: nil, sprint_on: nil, statuses: [], tag: nil)
        named = statuses.empty? && lists.any? ? OPEN : statuses
        tags = [tag.to_s.strip.downcase].reject(&:empty?)

        { lists:, sprint_on:, statuses: named, tags:, text: query.to_s.strip }
      end
    end
  end
end
