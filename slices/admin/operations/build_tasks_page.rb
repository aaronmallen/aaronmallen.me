# frozen_string_literal: true

module Admin
  module Operations
    class BuildTasksPage < Blog::Operation
      include Blog::Constants

      CARRIED = :carried_in
      COMPLETED = Blog::Types::TaskTab["completed"]
      FIELDS = %i[tag project contributor agent model].freeze
      FINISHED_TODAY = :finished_today
      NEXT = Blog::Types::TaskFilter["next"]
      RECURRING = Blog::Types::TaskTab["recurring"]
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]
      UNORDERED = [COMPLETED, RECURRING, UPCOMING].freeze
      UNSEEN = :unseen

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        next_cadence_date: "tasks.operations.next_cadence_date",
        search_query: "contracts.search_query_contract",
        sprint_queries: "tasks.repos.sprint_queries",
        task_queries: "tasks.repos.task_queries",
        task_series_queries: "tasks.repos.task_series_queries",
        task_source_queries: "tasks.repos.task_source_queries",
      ]

      def call(page:, tab: TODAY, pool: nil, query: nil, from: nil, to: nil, now: Time.now)
        sprint = step current_sprint.call(now:)
        today = Blog::TimeZone.today(now)
        planned = sprint_queries.after(today)
        filters = { query: Blog::Types::TrimmedText[query], **closed_range(from, to) }
        tasks = step listed(tab, sprint, planned, page, filters)

        pool = Blog::Types::TaskListParam[pool]

        {
          counts: counts(sprint, planned, today), filters:, lead: lead(tab, sprint, page, filters), tab:, tasks:,
          pool:, today:, **plan(tab, tasks, planned, page, pool), series: recurring(tab, today),
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
          UNSEEN => task_source_queries.unseen_task_count, RECURRING => task_series_queries.count,
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
                  when RECURRING then whole(EMPTY_ARRAY)
                  else task_queries.list(tab, sprint:, page:, **search)
                end

        tasks.past_end? ? Failure(:past_end) : Success(tasks)
      end

      def next_on(series, today)
        task = series.task

        task.closed? ? next_cadence_date.call(series.to_h, today) : task.sprint&.sprint_date
      end

      def plan(tab, tasks, planned, page, pool)
        {
          planned: tab == UPCOMING ? scheduled(tasks.rows, planned) : EMPTY_ARRAY,
          pools: tab == TODAY ? pools(pool, page) : EMPTY_HASH,
          waiting: tab == UPCOMING ? task_queries.list(NEXT, sprint: nil, page: first_page(page)).rows : EMPTY_ARRAY,
        }
      end

      def pools(pool, page) = { pool => task_queries.list(pool, sprint: nil, page: first_page(page)).rows }

      def recurring(tab, today)
        return EMPTY_ARRAY unless tab == RECURRING

        task_series_queries.listed.map { { series: it, next_on: next_on(it, today) } }
      end

      def scheduled(tasks, planned)
        held = tasks.group_by(&:sprint_id)

        planned.map { { sprint: it, tasks: held.fetch(it.id, EMPTY_ARRAY) } }
      end

      def whole(rows) = Blog::Structs::Paged.new(rows:, number: 1, more: false)
    end
  end
end
