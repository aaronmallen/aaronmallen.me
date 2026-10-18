# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class PageAction < Action
        include Redirect
        include Deps[build_task_page: "operations.build_task_page", task_view: "ui.views.tasks.show"]

        private

        def refuse(request, response, **state)
          case build_task_page.call(record_id(request), **state)
            in Success(page)
              unprocessable(response, task_view, **page, **return_to(request))
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end
