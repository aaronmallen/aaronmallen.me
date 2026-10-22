# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Index < Action
        include Deps[build_notes_page: "operations.build_notes_page"]

        def handle(_request, response) = response.render(view, **build_notes_page.call)
      end
    end
  end
end
