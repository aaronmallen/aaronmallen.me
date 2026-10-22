# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Index < Action
        include Deps[build_contacts_page: "operations.build_contacts_page"]

        def handle(request, response)
          response.render(view, **build_contacts_page.call(request.params))
        end
      end
    end
  end
end
