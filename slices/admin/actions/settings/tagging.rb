# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Tagging < Action
        include Deps["operations.build_tagging_page"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          page = requested_page(request, response)
          exposures = build_tagging_page.call(tags: { scope:, page:, query: request.params[:q] })
          not_found(response) if exposures[:tags][:tags].past_end?

          response.render(view, **exposures)
        end
      end
    end
  end
end
