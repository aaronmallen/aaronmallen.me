# frozen_string_literal: true

module Admin
  module Actions
    module TaskTypes
      class Create < Action
        ADDED = "task_types_page.toasts.added"

        include Deps[
          build_task_types_page: "operations.build_task_types_page",
          index_view: "ui.views.task_types.index",
          save_task_type: "tasks.operations.save_task_type",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:type]]

          case save_task_type.call(params)
          in Success(_)
            added(response)
          in Failure[:invalid, errors]
            invalid(response, params, errors)
          else halt 500
          end
        end

        private

        def added(response)
          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_task_types))
        end

        def invalid(response, params, errors)
          response.status = 422
          response.render(index_view, **build_task_types_page.call(errors:, params:))
        end
      end
    end
  end
end
