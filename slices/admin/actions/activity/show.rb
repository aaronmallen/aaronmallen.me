# frozen_string_literal: true

module Admin
  module Actions
    module Activity
      class Show < Action
        SCREEN = Blog::Types::SavedViewScreen["activity"]

        include Deps[
          build_activity_page: "operations.build_activity_page", list_saved_views: "operations.list_saved_views",
        ]

        def handle(request, response)
          params = request.params

          response.render(
            view,
            **build_activity_page.call(
              from: params[:from], to: params[:to], types: params[:types], query: params[:q], day: params[:day],
            ),
            saved_views: list_saved_views.call(SCREEN, params),
          )
        end
      end
    end
  end
end
