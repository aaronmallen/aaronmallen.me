# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Show < Action
        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          project = project_queries.by_id(record_id(request))
          not_found(response) unless project

          response.render(view, project:, tasks: task_queries.on_board(project.id))
        end
      end
    end
  end
end
