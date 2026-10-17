# frozen_string_literal: true

module Public
  module Actions
    module Projects
      class Show < Action
        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        share_with_caches

        def handle(request, response)
          project = project_queries.public_board(path_param(request, :slug))
          response.status = :not_found unless project

          response[:project] = project
          expose_board(response, project&.id, Blog::BoardSizes.from(request.params, settings.board[:column_size]))
        end

        private

        def expose_board(response, project_id, board)
          response[:board] = board
          response[:counts] = project_id ? task_queries.board_counts(project_id) : {}
          response[:tasks] = project_id ? task_queries.on_public_board(project_id, board.sizes) : []
        end
      end
    end
  end
end
