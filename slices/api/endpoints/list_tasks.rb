# frozen_string_literal: true

module API
  module Endpoints
    class ListTasks < Endpoint
      BAD_SPRINT_DAY = "give sprint_on as a day, such as 2026-01-01"
      CONTRIBUTORS = Blog::Types::ContributorKind.values.freeze
      LISTS = Blog::Types::TaskList.values.freeze
      OPEN = [Blog::Types::TaskStatus["open"], Blog::Types::TaskStatus["in_progress"]].freeze
      STATUSES = Blog::Types::TaskStatus.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::WINDOW,
          agent: { type: "string", description: "an agent, such as claude-code; only the tasks it worked on" },
          contributor: {
            type: "string",
            enum: CONTRIBUTORS,
            description: "owner or agent; owner also keeps every task that lists no contributors",
          },
          lists: {
            type: "array",
            items: { type: "string", enum: LISTS },
            description: "next, someday or external; open tasks unless you name statuses; every list when left out",
          },
          model: { type: "string", description: "a model, such as claude-opus-5-5; only the tasks it worked on" },
          page: Blog::Helpers::Paging::PAGE,
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

      REPLY = Helpers::Schema.object(
        {
          count: Helpers::Schema::INTEGER,
          total: Helpers::Schema::INTEGER,
          tasks: Helpers::Schema.list(Serializers::Task.reference),
          partial: Helpers::Schema::BOOLEAN,
        },
        optional: { next_page: Helpers::Schema::INTEGER },
      ).freeze

      include Deps["settings", task_queries: "tasks.repos.task_queries"]

      def handle(from: nil, page: 1, sprint_on: nil, to: nil, **filters)
        day = sprint_on && Blog::TimeZone.parse_day(sprint_on)
        return invalid(sprint_on: [BAD_SPRINT_DAY]) if sprint_on && day.nil?

        case Blog::Helpers::DayWindow.open_days(from, to)
          in Success[first, last] then Success(listed(narrowed(**filters, sprint_on: day), first, last, page))
          in Failure(message) then invalid(from: [message], to: [message])
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
          total: found.total,
          tasks: serialized(Serializers::Task, rows),
          **Blog::Helpers::Paging.fields(found.paged),
        }
      end

      def named(value) = [value.to_s.strip.downcase].reject(&:empty?)

      def narrowed(lists: [], query: nil, sprint_on: nil, statuses: [], tag: nil, **credited)
        kept = statuses.empty? && lists.any? ? OPEN : statuses

        { lists:, sprint_on:, statuses: kept, tags: named(tag), text: query.to_s.strip, **credits(**credited) }
      end
    end
  end
end
