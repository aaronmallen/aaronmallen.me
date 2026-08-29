# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class New < Action
        include Deps[build_project_editor: "operations.build_project_editor"]

        def handle(_request, response)
          response.render(view, **build_project_editor.call)
        end
      end
    end
  end
end
