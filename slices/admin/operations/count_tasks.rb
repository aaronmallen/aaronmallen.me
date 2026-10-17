# frozen_string_literal: true

module Admin
  module Operations
    class CountTasks < Blog::Operation
      WHOLE = [BuildTasksPage::RECURRING, BuildTasksPage::UPCOMING].freeze

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        search_query: "contracts.search_query_contract",
        task_count_queries: "tasks.repos.task_count_queries",
      ]

      def call(tab:, query:, now: Time.now)
        return Float::INFINITY if WHOLE.include?(tab)

        sprint = step current_sprint.call(now:)
        search = search_query.call(query:, fields: BuildTasksPage::FIELDS).to_h

        task_count_queries.on_tab(tab, sprint:, **search)
      end
    end
  end
end
