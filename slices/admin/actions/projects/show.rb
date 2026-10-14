# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Show < Action
        COLUMNS = Blog::Types::TaskColumn.values

        include Deps[project_queries: "projects.repos.project_queries", task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          project = project_queries.by_id(record_id(request))
          not_found(response) unless project

          sizes = sizes(request)
          response.render(view, project:, sizes:, step: column_size, counts: task_queries.board_counts(project.id),
                                tasks: task_queries.on_board(project.id, sizes))
        end

        private

        def column_size = settings.board[:column_size]

        def sizes(request)
          COLUMNS.to_h { [it, [column_size, Blog::Types::BoardSizeParam[request.params[it.to_sym]].to_i].max] }
        end
      end
    end
  end
end
