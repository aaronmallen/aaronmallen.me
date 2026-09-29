# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Show < Action
        include Redirect
        include Deps[build_task_page: "operations.build_task_page"]

        def handle(request, response)
          case build_task_page.call(record_id(request), query: request.params[:link_q], kind: kind(request))
          in Success(page) then response.render(view, **page, **return_to(request))
          in Failure(:not_found) then not_found(response)
          else halt 500
          end
        end

        private

        def kind(request) = Blog::Types::Text[request.params[:link_kind]]
      end
    end
  end
end
