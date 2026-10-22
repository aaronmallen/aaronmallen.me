# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class FolderMenu < Action
        include Deps[build_notes_page: "operations.build_notes_page"]

        def handle(request, response)
          tree = build_notes_page.tree
          folder = tree.find(record_id(request)) || halt(:not_found)

          shut = Blog::Types::Checkbox[request.params[:shut]]

          response.render(view, folder:, tree:, shut:, return_to: back_here(request))
        end
      end
    end
  end
end
