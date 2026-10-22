# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class RemoveFolder < Action
        REMOVED = "notes_page.toasts.folder_removed"

        include Place
        include Deps[
          note_queries: "notes.repos.note_queries",
          remove_note_folder: "notes.operations.remove_note_folder",
        ]

        def handle(request, response)
          id = record_id(request)
          parent_id = note_queries.folder_by_id(id)&.parent_id

          settle(response, remove_note_folder.call(id), REMOVED, after(request, id, parent_id))
        end

        private

        def after(request, id, parent_id)
          back = back(request)
          return back unless back == routes.path(:admin_note_folder, id:)

          parent_id ? routes.path(:admin_note_folder, id: parent_id) : routes.path(:admin_notes)
        end
      end
    end
  end
end
