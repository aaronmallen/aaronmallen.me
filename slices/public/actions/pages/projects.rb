# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Projects < Action
        include Deps[
          public_archived_projects: "projects.queries.public_archived",
          public_project_grid: "projects.queries.public_grid",
        ]

        share_with_caches

        def handle(_request, response)
          response[:projects] = public_project_grid.call
          response[:past_projects] = public_archived_projects.call
        end
      end
    end
  end
end
