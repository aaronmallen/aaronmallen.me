# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class FolderMenu < Action
        KIND = Blog::Types::RecordKind["note_folder"]

        include Deps[
          build_notes_page: "operations.build_notes_page",
          record_link_queries: "links.repos.record_link_queries",
        ]

        def handle(request, response)
          tree = build_notes_page.tree
          folder = tree.find(record_id(request)) || halt(:not_found)

          shut = Blog::Types::Checkbox[request.params[:shut]]

          links = record_link_queries.counts(KIND, [folder.id]).fetch(folder.id, 0)

          response.render(view, folder:, tree:, shut:, links:, return_to: back_here(request))
        end
      end
    end
  end
end
