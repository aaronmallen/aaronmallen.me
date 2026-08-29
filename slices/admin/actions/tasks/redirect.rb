# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      module Redirect
        FROM_TODAY = Blog::Types::TaskOrigin["today"]

        private

        def from_today?(request) = Blog::Types::TaskOriginParam[request.params[:origin]] == FROM_TODAY

        def task_tab(request) = Blog::Types::TaskTabParam[request.params[:filter]]

        def tasks_path(request, filter: nil)
          return routes.path(:admin_root) if from_today?(request)

          routes.path(:admin_tasks, filter: filter || task_tab(request))
        end
      end
    end
  end
end
