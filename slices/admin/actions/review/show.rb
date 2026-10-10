# frozen_string_literal: true

module Admin
  module Actions
    module Review
      class Show < Action
        include Deps[build_review_page: "operations.build_review_page"]

        def handle(request, response)
          params = request.params
          page = build_review_page.call(**params.to_h.slice(:period, :day, :focus, :by))

          response.render(view, **page, group: Blog::Types::ReviewGroupParam[params[:group]])
        end
      end
    end
  end
end
