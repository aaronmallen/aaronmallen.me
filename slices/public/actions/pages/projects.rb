# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Projects < Action
        include Deps[project_queries: "projects.repos.project_queries"]

        share_with_caches

        def handle(_request, response)
          response[:projects] = project_queries.public_grid
          response[:past_projects] = project_queries.public_archived
        end
      end
    end
  end
end
