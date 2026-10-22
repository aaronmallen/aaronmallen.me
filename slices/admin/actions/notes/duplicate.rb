# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Duplicate < Action
        DUPLICATED = "notes_page.toasts.duplicated"

        include Place
        include Deps[duplicate_note: "notes.operations.duplicate_note"]

        def handle(request, response)
          case duplicate_note.call(record_id(request))
            in Success(note) then toast_back(response, DUPLICATED, routes.path(:admin_note, id: note.id))
            in Failure[:invalid, errors] then refused(request, response, errors)
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end
