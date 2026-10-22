# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Show < Action
        include Deps[build_contact_page: "operations.build_contact_page"]

        def handle(request, response)
          page = build_contact_page.call(record_id(request))
          not_found(response) unless page

          response.render(view, **page)
        end
      end
    end
  end
end
