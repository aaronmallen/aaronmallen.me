# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Show < Action
        include Redirect
        include Deps[build_task_page: "operations.build_task_page"]

        def handle(request, response)
          page = build_task_page.call(record_id(request), query: request.params[:link_q])
          not_found(response) unless page

          response.render(view, **page, **return_to(request))
        end
      end
    end
  end
end
