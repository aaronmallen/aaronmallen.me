# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Index < Action
        include Deps["settings", build_tasks_page: "operations.build_tasks_page"]

        def handle(request, response)
          case build(request, response)
          in Success(screen) then response.render(view, **screen)
          in Failure(:past_end) then not_found(response)
          else halt 500
          end
        end

        private

        def build(request, response)
          build_tasks_page.call(
            page: requested_page(request, response, settings.page_size[:admin]),
            tab: Blog::Types::TaskTabParam[request.params[:filter]],
            pool: request.params[:pool],
            query: request.params[:q],
          )
        end
      end
    end
  end
end
