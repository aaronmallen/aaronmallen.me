# frozen_string_literal: true

module Public
  module Actions
    module Projects
      class Show < Action
        COLUMNS = Blog::Types::TaskColumn.values
        NOT_PUBLIC = 404

        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        share_with_caches

        def handle(request, response)
          project = project_queries.public_board(path_param(request, :slug))
          response.status = NOT_PUBLIC unless project

          response[:project] = project
          expose_board(response, project&.id, sizes(request))
        end

        private

        def column_size = settings.board[:column_size]

        def expose_board(response, project_id, sizes)
          response[:sizes] = sizes
          response[:step] = column_size
          response[:counts] = project_id ? task_queries.board_counts(project_id) : {}
          response[:tasks] = project_id ? task_queries.on_public_board(project_id, sizes) : []
        end

        def sizes(request)
          COLUMNS.to_h { [it, [column_size, Blog::Types::BoardSizeParam[request.params[it.to_sym]].to_i].max] }
        end
      end
    end
  end
end
