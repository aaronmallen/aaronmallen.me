# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Index < Action
        SCREEN = Blog::Types::SavedViewScreen["tasks"]

        include Deps[
          build_tasks_page: "operations.build_tasks_page", list_saved_views: "operations.list_saved_views",
        ]

        def handle(request, response)
          case build(request, response)
            in Success(screen) then show_page(request, response, screen)
            in Failure(:past_end) then not_found(response)
            else halt 500
          end
        end

        private

        def build(request, response)
          build_tasks_page.call(
            page: requested_page(request, response),
            tab: Blog::Types::TaskTabParam[request.params[:filter]],
            pool: request.params[:pool],
            query: request.params[:q],
            from: Blog::Types::DateParam[request.params[:from]],
            to: Blog::Types::DateParam[request.params[:to]],
          )
        end

        def show_page(request, response, screen)
          filters = { **screen[:filters], saved_views: list_saved_views.call(SCREEN, request.params) }

          response.render(view, **screen, filters:)
        end
      end
    end
  end
end
