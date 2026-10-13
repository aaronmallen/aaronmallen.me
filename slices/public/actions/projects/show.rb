# frozen_string_literal: true

module Public
  module Actions
    module Projects
      class Show < Action
        NOT_PUBLIC = 404

        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        share_with_caches

        def handle(request, response)
          project = project_queries.public_board(path_param(request, :slug))
          response.status = NOT_PUBLIC unless project

          response[:project] = project
          response[:tasks] = project ? task_queries.on_public_board(project.id) : []
        end
      end
    end
  end
end
