# frozen_string_literal: true

module Admin
  module Actions
    module Activity
      class Show < Action
        include Deps[build_activity_page: "operations.build_activity_page"]

        def handle(request, response)
          params = request.params

          response.render(
            view,
            **build_activity_page.call(
              from: params[:from], to: params[:to], types: params[:types], query: params[:q], day: params[:day],
            ),
          )
        end
      end
    end
  end
end
