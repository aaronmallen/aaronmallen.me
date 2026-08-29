# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class New < Action
        include Deps[build_post_editor: "operations.build_post_editor"]

        def handle(_request, response)
          response.render(view, **build_post_editor.call)
        end
      end
    end
  end
end
