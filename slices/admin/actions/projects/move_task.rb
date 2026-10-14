# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class MoveTask < Action
        MOVED = "projects_page.toasts.moved"

        include Deps[
          set_task_column: "tasks.operations.set_task_column",
          task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:task_id]] || halt(404)
          column = Blog::Types::TaskColumnParam[request.params[:to]] || halt(422)

          case set_task_column.call(id, column)
            in Success(_) then moved(request, response, id, column)
            in Failure(:not_found) then halt 404
            else halt 500
          end
        end

        private

        def moved(request, response, id, column)
          column_name = i18n.t!(UI::Components::Projects::BoardCard::NAMES.fetch(column))

          toast(response, MOVED, key: task_queries.by_id(id).label, column: column_name)
          response.redirect_to(back_here(request) || routes.path(:admin_project, id: record_id(request)))
        end
      end
    end
  end
end
