# frozen_string_literal: true

module Admin
  module Actions
    module People
      class New < Action
        include Deps[build_person_editor: "operations.build_person_editor"]

        def handle(_request, response)
          response.render(view, **build_person_editor.call)
        end
      end
    end
  end
end
