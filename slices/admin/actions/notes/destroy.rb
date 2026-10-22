# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Destroy < Action
        DELETED = "notes_page.toasts.deleted"

        include Place
        include Deps[delete_note: "notes.operations.delete_note"]

        def handle(request, response)
          id = record_id(request)
          gone = routes.path(:admin_note, id:)
          back = back(request)
          back = routes.path(:admin_notes) if back.split("?").first == gone

          settle(response, delete_note.call(id), DELETED, back)
        end
      end
    end
  end
end
