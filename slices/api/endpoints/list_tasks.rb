# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      LISTS = Blog::Types::TaskList.values.freeze
      OPEN = Blog::Types::OpenTaskStatus.values.freeze
      STATUSES = Blog::Types::TaskStatus.values.freeze
      WINDOW_BY = %w[touched closed].freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Helpers::DayWindow::WINDOW,
          **Helpers::Schema::CREDITS,
          lists: {
            type: "array",
            items: { type: "string", enum: LISTS },
            description: "next, someday or external; open tasks unless you name statuses; every list when left out",
          },
          page: Helpers::Paging::PAGE,
          query: {
            type: "string",
            description:
              "terms that must all hold: words or a quoted phrase to find in the title or note, a label such " \
              "as POD-23 or a number, which comes first, label:a,b or l: for a tag of those, -label:a without " \
              "it, no:label, is:open, is:closed, is:doing, is:blocked, and column: or col: with backlog, " \
              "ready, in_progress, done or canceled; a - before a qualifier turns it round, and ignored lists " \
              "the terms it does not know",
          },
          sprint_on: { type: "string", description: "a sprint day, as YYYY-MM-DD; only the tasks planned into it" },
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
          tag: { type: "string", description: "a tag the task carries; any tag when you leave it out" },
          window_by: {
            type: "string",
            enum: WINDOW_BY,
            description: "touched (the default) keeps a task made or finished in the window, closed one finished in it",
          },
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          count: Helpers::Schema::INTEGER,
          ignored: Helpers::Schema.list(Helpers::Schema::STRING).merge(
            description: "the terms of query it does not know and left out",
          ),
          total: Helpers::Schema::INTEGER,
          tasks: Helpers::Schema.list(Serializers::Task.reference),
        },
      ).freeze

      include Deps[task_queries: "tasks.repos.task_queries"]

      def handle(from: nil, page: 1, sprint_on: nil, to: nil, **filters)
        day = sprint_on && Blog::TimeZone.parse_day(sprint_on)
        return invalid(sprint_on: [Tasks::SPRINT_DAY]) if sprint_on && day.nil?

        case Helpers::DayWindow.open_days(from, to)
          in Success[first, last] then Success(listed(narrowed(**filters, sprint_on: day), first, last, page))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def credits(contributor: nil, agent: nil, model: nil)
        { contributors: named(contributor), agents: named(agent), models: named(model) }
      end

      def listed(filters, from, to, number)
        found = task_queries.filtered(**filters, from:, to:, page: page_of(number))
        rows = found.paged.rows

        {
          count: rows.length,
          ignored: filters[:query].ignored,
          total: found.total,
          tasks: serialized(Serializers::Task, rows),
          **Helpers::Paging.fields(found.paged),
        }
      end

      def named(value) = [value.to_s.strip.downcase].reject(&:empty?)

      def narrowed(lists: [], query: nil, sprint_on: nil, statuses: [], tag: nil, window_by: nil, **credited)
        kept = statuses.empty? && lists.any? ? OPEN : statuses
        closed_in_window = window_by == "closed"

        {
          closed_in_window:, lists:, sprint_on:, statuses: kept, tags: named(tag),
          query: ::Tasks::Structs::TaskQuery.parse(query), **credits(**credited),
        }
      end
    end
  end
end
