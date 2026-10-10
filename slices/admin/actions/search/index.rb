# frozen_string_literal: true

module Admin
  module Actions
    module Search
      class Index < Action
        include Deps[build_search_page: "operations.build_search_page"]

        def handle(request, response)
          kind = Blog::Types::SearchKindParam[request.params[:kind]]
          page = requested_page(request, response)
          exposures = build_search_page.call(query: request.params[:q], kind:, page:)
          not_found(response) if exposures[:results].past_end?

          response.render(view, **exposures)
        end
      end
    end
  end
end
