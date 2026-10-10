# frozen_string_literal: true

module Admin
  module Operations
    class BuildTasksPage < Operation
      include Blog::Constants

      CARRIED = :carried_in
      COMPLETED = Blog::Types::TaskTab["completed"]
      FIELDS = %i[tag project contributor agent model].freeze
      FINISHED_TODAY = :finished_today
      NEXT = Blog::Types::TaskFilter["next"]
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]
      UNORDERED = [COMPLETED, UPCOMING].freeze
      UNSEEN = :unseen

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        search_query: "contracts.search_query_contract",
        sprint_queries: "tasks.repos.sprint_queries",
        task_queries: "tasks.repos.task_queries",
        task_source_queries: "tasks.repos.task_source_queries",
      ]

      def call(page:, tab: TODAY, pool: nil, query: nil, from: nil, to: nil, now: Time.now)
        sprint = step current_sprint.call(now:)
        today = Blog::TimeZone.today(now)
        planned = sprint_queries.after(today)
        filters = { query: Blog::Types::TrimmedText[query], **closed_range(from, to) }
        tasks = step listed(tab, sprint, planned, page, filters)

        {
          counts: counts(sprint, planned, today), filters:, lead: lead(tab, sprint, page, filters), tab:, tasks:,
          pool: Blog::Types::TaskListParam[pool], today:, **plan(tab, tasks, planned, page),
        }
      end

      private

      def closed_range(from, to)
        range = ::Tasks::Contracts::ClosedRangeContract.new.call(from:, to:)

        range.success? ? range.to_h : { from: nil, to: nil }
      end

      def counts(sprint, planned, today)
        finished = task_queries.finished_counts(today)

        task_queries.open_counts(sprint:, planned:).merge(
          COMPLETED => finished.fetch(:total), FINISHED_TODAY => finished.fetch(:on_day), CARRIED => sprint.carried_in,
          UNSEEN => task_source_queries.unseen_task_count,
        )
      end

      def first_page(page) = Blog::Structs::Page.new(number: 1, size: page.size)

      def lead(tab, sprint, page, filters)
        return if page.number == 1 || UNORDERED.include?(tab) || !filters[:query].empty?

        previous = Blog::Structs::Page.new(number: page.number - 1, size: page.size)

        task_queries.list(tab, sprint:, page: previous).rows.last&.id
      end

      def listed(tab, sprint, planned, page, filters)
        search = search_query.call(query: filters[:query], fields: FIELDS).to_h
        tasks = case tab
                  when COMPLETED then task_queries.finished(page:, **filters.slice(:from, :to), **search)
                  when UPCOMING then whole(task_queries.planned(planned, **search))
                  else task_queries.list(tab, sprint:, page:, **search)
                end

        tasks.past_end? ? Failure(:past_end) : Success(tasks)
      end

      def plan(tab, tasks, planned, page)
        {
          planned: tab == UPCOMING ? scheduled(tasks.rows, planned) : EMPTY_ARRAY,
          pools: tab == TODAY ? pools(page) : EMPTY_HASH,
          waiting: tab == UPCOMING ? task_queries.list(NEXT, sprint: nil, page: first_page(page)).rows : EMPTY_ARRAY,
        }
      end

      def pools(page)
        Blog::Types::TaskList.values.to_h { [it, task_queries.list(it, sprint: nil, page: first_page(page)).rows] }
      end

      def scheduled(tasks, planned)
        held = tasks.group_by(&:sprint_id)

        planned.map { { sprint: it, tasks: held.fetch(it.id, EMPTY_ARRAY) } }
      end

      def whole(rows) = Blog::Structs::Paged.new(rows:, number: 1, more: false)
    end
  end
end
