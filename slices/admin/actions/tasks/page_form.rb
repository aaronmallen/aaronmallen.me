# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      module PageForm
        include Dry::Monads[:result]

        private

        def refuse(request, response, **state)
          case build_task_page.call(record_id(request), **state)
          in Success(page)
            response.status = 422
            response.render(task_view, **page, **return_to(request))
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        def written(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end
      end
    end
  end
end
