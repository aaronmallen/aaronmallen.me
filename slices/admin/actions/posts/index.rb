# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Index < Action
        include Deps["settings", build_posts_page: "operations.build_posts_page"]

        def handle(request, response)
          page = requested_page(request, response, settings.page_size[:admin])
          exposures = build_posts_page.call(filter: request.params[:status], page:)
          not_found(response) if exposures[:posts].past_end?

          response.render(view, **exposures)
        end
      end
    end
  end
end
