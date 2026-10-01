# frozen_string_literal: true

module Admin
  module Operations
    class BuildTasksPage < Blog::Operation
      include Blog::Constants

      CARRIED = :carried_in
      COMPLETED = Blog::Types::TaskTab["completed"]
      FIELDS = %i[tag].freeze
      FINISHED_TODAY = :finished_today
      NEXT = Blog::Types::TaskFilter["next"]
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]
      UNORDERED = [COMPLETED, UPCOMING].freeze

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        finished_task_counts: "tasks.queries.finished_task_counts",
        list_finished_tasks: "tasks.queries.list_finished_tasks",
        list_tasks: "tasks.queries.list_tasks",
        open_task_counts: "tasks.queries.open_task_counts",
        planned_tasks: "tasks.queries.planned_tasks",
        sprints_after: "tasks.queries.sprints_after",
      ]

      def call(page:, tab: TODAY, pool: nil, query: nil, now: Time.now)
        sprint = step current_sprint.call(now:)
        today = Blog::TimeZone.today(now)
        planned = sprints_after.call(today)
        filters = { query: Blog::Types::TrimmedText[query] }
        tasks = step listed(tab, sprint, planned, page, SearchQuery.parse(filters[:query], fields: FIELDS))

        {
          counts: counts(sprint, planned, today), filters:, lead: lead(tab, sprint, page, filters), tab:, tasks:,
          pool: Blog::Types::TaskListParam[pool], today:, **plan(tab, tasks, planned, page),
        }
      end

      private

      def counts(sprint, planned, today)
        finished = finished_task_counts.call(today)

        open_task_counts.call(sprint:, planned:).merge(
          COMPLETED => finished.fetch(:total), FINISHED_TODAY => finished.fetch(:on_day), CARRIED => sprint.carried_in,
        )
      end

      def first_page(page) = Blog::Page.new(number: 1, size: page.size)

      def lead(tab, sprint, page, filters)
        return if page.number == 1 || UNORDERED.include?(tab) || !filters[:query].empty?

        list_tasks.call(tab, sprint:, page: Blog::Page.new(number: page.number - 1, size: page.size)).rows.last&.id
      end

      def listed(tab, sprint, planned, page, search)
        tasks = case tab
                when COMPLETED then list_finished_tasks.call(page:, **search)
                when UPCOMING then whole(planned_tasks.call(planned, **search))
                else list_tasks.call(tab, sprint:, page:, **search)
                end

        tasks.past_end? ? Failure(:past_end) : Success(tasks)
      end

      def plan(tab, tasks, planned, page)
        {
          planned: tab == UPCOMING ? scheduled(tasks.rows, planned) : EMPTY_ARRAY,
          pools: tab == TODAY && tasks.rows.empty? ? pools(page) : EMPTY_HASH,
          waiting: tab == UPCOMING ? list_tasks.call(NEXT, sprint: nil, page: first_page(page)).rows : EMPTY_ARRAY,
        }
      end

      def pools(page)
        Blog::Types::TaskList.values.to_h { [it, list_tasks.call(it, sprint: nil, page: first_page(page)).rows] }
      end

      def scheduled(tasks, planned)
        held = tasks.group_by(&:sprint_id)

        planned.map { { sprint: it, tasks: held.fetch(it.id, EMPTY_ARRAY) } }
      end

      def whole(rows) = Blog::Paged.new(rows:, number: 1, more: false)
    end
  end
end
