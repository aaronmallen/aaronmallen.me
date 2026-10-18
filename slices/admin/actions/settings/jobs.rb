# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Jobs < Action
        include Deps[job_queries: "activity.repos.job_queries"]

        def handle(_request, response) = response.render(view, health: job_queries.health)
      end
    end
  end
end
