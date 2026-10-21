# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Show < Action
        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          project = project_queries.by_id(record_id(request))
          not_found(response) unless project

          board = Blog::BoardSizes.from(request.params, settings.board[:column_size])
          response.render(view, project:, board:, view: board_view(request), **on_board(project.id, board))
        end

        private

        def board_view(request) = request.params[:view].then { it if UI::Views::Projects::Show::VIEWS.key?(it) }

        def on_board(id, board)
          { counts: task_queries.board_counts(id), tasks: task_queries.on_board(id, board.sizes) }
        end
      end
    end
  end
end
