# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Index < Action
        SCREEN = Blog::Types::SavedViewScreen["posts"]

        include Deps[
          build_posts_page: "operations.build_posts_page", list_saved_views: "operations.list_saved_views",
        ]

        def handle(request, response)
          page = requested_page(request, response)
          exposures = build_posts_page.call(filter: request.params[:status], page:)
          not_found(response) if exposures[:posts].past_end?

          response.render(view, **exposures, saved_views: list_saved_views.call(SCREEN, request.params))
        end
      end
    end
  end
end
