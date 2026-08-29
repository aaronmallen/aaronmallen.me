# frozen_string_literal: true

module Admin
  module Actions
    module TaskTypes
      class Update < Action
        RENAMED = "task_types_page.toasts.renamed"

        include Deps[
          build_task_types_page: "operations.build_task_types_page",
          index_view: "ui.views.task_types.index",
          save_task_type: "tasks.operations.save_task_type",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:type]]

          case save_task_type.call(params, id:)
          in Success(_) then renamed(response)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, id, params, errors)
          else halt 500
          end
        end

        private

        def editing(id, params, errors)
          { errors:, icon: Blog::Types::OptionalText[params[:icon]], id:, name: Blog::Types::Text[params[:name]] }
        end

        def invalid(response, id, params, errors)
          response.status = 422
          response.render(index_view, **build_task_types_page.call(editing: editing(id, params, errors)))
        end

        def renamed(response)
          toast(response, RENAMED)
          response.redirect_to(routes.path(:admin_task_types))
        end
      end
    end
  end
end
