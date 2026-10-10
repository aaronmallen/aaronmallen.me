# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Index < Action
        include Deps[build_tags_page: "operations.build_tags_page"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          page = requested_page(request, response)
          exposures = build_tags_page.call(scope:, page:, query: request.params[:q])
          not_found(response) if exposures[:tags].past_end?

          response.render(view, **exposures)
        end
      end
    end
  end
end
