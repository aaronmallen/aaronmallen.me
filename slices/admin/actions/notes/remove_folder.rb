# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class RemoveFolder < Action
        REMOVED = "notes_page.toasts.folder_removed"

        include Place
        include Deps[remove_note_folder: "notes.operations.remove_note_folder"]

        def handle(request, response)
          settle(response, remove_note_folder.call(record_id(request)), REMOVED, back(request))
        end
      end
    end
  end
end
