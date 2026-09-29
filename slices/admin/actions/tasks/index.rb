# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Index < Action
        include Deps[build_tasks_page: "operations.build_tasks_page"]

        def handle(request, response)
          tab = Blog::Types::TaskTabParam[request.params[:filter]]

          page = build_tasks_page.call(
            tab:, linking: linking(request), pool: request.params[:pool], query: request.params[:q],
          )

          case page
          in Success(screen) then response.render(view, **screen)
          else halt 500
          end
        end

        private

        def linking(request)
          id = Blog::Types::IdParam[request.params[:link]]

          { id:, query: Blog::Types::TrimmedText[request.params[:link_q]] } if id
        end
      end
    end
  end
end
