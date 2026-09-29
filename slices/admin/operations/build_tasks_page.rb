# frozen_string_literal: true

module Admin
  module Operations
    class BuildTasksPage < Blog::Operation
      include Dry::Core::Constants

      CARRIED = :carried_in
      COMPLETED = Blog::Types::TaskTab["completed"]
      FIELDS = %i[tag].freeze
      FINISHED_TODAY = :finished_today
      NEXT = Blog::Types::TaskFilter["next"]
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        finished_task_counts: "tasks.queries.finished_task_counts",
        link_targets: "tasks.queries.link_targets",
        list_finished_tasks: "tasks.queries.list_finished_tasks",
        list_tasks: "tasks.queries.list_tasks",
        search_tasks: "tasks.queries.search_tasks",
        sprints_after: "tasks.queries.sprints_after",
      ]

      def call(tab: TODAY, editing: nil, linking: nil, pool: nil, query: nil, now: Time.now)
        sprint = step current_sprint.call(now:)
        open = open_lists(sprint)
        filters = { query: Blog::Types::TrimmedText[query] }

        {
          editing:, filters:, linking: link_picker(linking), tab:, tasks: filtered(listed(tab, open), filters),
          **screen(open, sprint, pool, Blog::TimeZone.today(now)),
        }
      end

      private

      def counts(open, sprint, today)
        finished = finished_task_counts.call(today)

        open.transform_values(&:size).merge(
          COMPLETED => finished.fetch(:total), FINISHED_TODAY => finished.fetch(:on_day), CARRIED => sprint.carried_in,
        )
      end

      def filtered(tasks, filters)
        found = matching(filters[:query])

        found.nil? ? tasks : tasks.select { found.include?(it.id) }
      end

      def link_picker(linking)
        return nil if linking.nil?

        query = linking.fetch(:query, EMPTY_STRING)

        { errors: EMPTY_HASH, kind: nil, **linking, query:, targets: link_targets.call(linking.fetch(:id), query) }
      end

      def listed(tab, open) = tab == COMPLETED ? list_finished_tasks.call : open.fetch(tab)

      def matching(query)
        return nil if query.empty?

        search_tasks.call(**SearchQuery.parse(query, fields: FIELDS)).to_set(&:id)
      end

      def open_lists(sprint) = list_tasks.call(sprint:).transform_values { |tasks| tasks.reject(&:closed?) }

      def planned(tasks, today)
        held = tasks.group_by(&:sprint_id)

        sprints_after.call(today).map { { sprint: it, tasks: held.fetch(it.id, EMPTY_ARRAY) } }
      end

      def pools(open) = Blog::Types::TaskList.values.to_h { [it, open.fetch(it)] }

      def screen(open, sprint, pool, today)
        {
          counts: counts(open, sprint, today),
          planned: planned(open.fetch(UPCOMING), today),
          pool: Blog::Types::TaskListParam[pool],
          pools: pools(open),
          today:,
          waiting: open.fetch(NEXT),
        }
      end
    end
  end
end
