# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Index < Action
        include Deps[build_links_page: "operations.build_links_page"]

        def handle(request, response)
          page = requested_page(request, response)
          exposures = build_links_page.call(page:, **request.params.to_h.slice(:sort, :filter, :search))
          not_found(response) if exposures[:links].past_end?

          response.render(view, **exposures)
        end

        private

        def page_size = Operations::BuildLinksPage::PAGE_SIZE
      end
    end
  end
end
