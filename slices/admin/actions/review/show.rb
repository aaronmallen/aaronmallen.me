# frozen_string_literal: true

module Admin
  module Actions
    module Review
      class Show < Action
        include Deps[build_review_page: "operations.build_review_page"]

        def handle(request, response)
          params = request.params

          response.render(
            view,
            **build_review_page.call(
              period: params[:period], day: params[:day],
              contributor: params[:contributor], agent: params[:agent], model: params[:model],
            ),
          )
        end
      end
    end
  end
end
