# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      module Redirect
        FROM_TODAY = Blog::Types::TaskOrigin["today"]

        private

        def from_today?(request) = Blog::Types::TaskOriginParam[request.params[:origin]] == FROM_TODAY

        def return_to(request) = { filter: task_tab(request), origin: task_origin(request) }

        def task_origin(request) = Blog::Types::TaskOriginParam[request.params[:origin]]

        def task_page(request) = Blog::Types::PageParam.call(request.params[:page]) { 1 }

        def task_tab(request) = Blog::Types::TaskTabParam[request.params[:filter]]

        def tasks_path(request, filter: nil, pool: nil, page: 1)
          query = pool ? { pool: } : {}
          return routes.path(:admin_root, **query) if from_today?(request)

          routes.path(:admin_tasks, filter: filter || task_tab(request), **query, **Blog::Page.query(page))
        end
      end
    end
  end
end
