# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Edit < Show
        FRESH = { errors: Blog::Constants::EMPTY_HASH, values: nil }.freeze
        PARTS = %i[task timeline forms linking].freeze

        include Deps[task_series_queries: "tasks.repos.task_series_queries"]

        private

        def shown(page) = page.slice(*PARTS).merge(FRESH, series: task_series_queries.by_task(page[:task].id))
      end
    end
  end
end
