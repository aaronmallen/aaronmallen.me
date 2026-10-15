# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      module Redirect
        FROM_INBOX = Blog::Types::TaskOrigin["inbox"]
        FROM_TODAY = Blog::Types::TaskOrigin["today"]

        private

        def from_today?(request) = Blog::Types::TaskOriginParam[request.params[:origin]] == FROM_TODAY

        def redirect_with(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end

        def return_to(request) = { filter: task_tab(request), origin: task_origin(request) }

        def task_origin(request) = Blog::Types::TaskOriginParam[request.params[:origin]]

        def task_tab(request) = Blog::Types::TaskTabParam[request.params[:filter]]

        def tasks_path(request, filter: nil, pool: nil)
          back = back_here(request)
          return back if back
          return routes.path(:admin_inbox) if task_origin(request) == FROM_INBOX

          query = pool ? { pool: } : {}
          return routes.path(:admin_root, **query) if from_today?(request)

          routes.path(:admin_tasks, filter: filter || task_tab(request), **query)
        end
      end
    end
  end
end
