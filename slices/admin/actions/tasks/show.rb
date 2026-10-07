# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Show < Action
        include Redirect
        include Deps[build_task_page: "operations.build_task_page"]

        def handle(request, response)
          case build_task_page.call(record_id(request), **page_params(request))
            in Success(page) then response.render(view, **page, **return_to(request))
            in Failure(:not_found) then not_found(response)
            else halt 500
          end
        end

        private

        def page_params(request)
          params = request.params

          { query: params[:link_q], kind: Blog::Types::Text[params[:link_kind]], records: { query: params[:record_q] } }
        end
      end
    end
  end
end
