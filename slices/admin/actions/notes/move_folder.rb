# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class MoveFolder < Action
        include Place
        include Deps[
          "notes.operations.create_note_folder_path",
          move_note_folder: "notes.operations.move_note_folder",
        ]

        def handle(request, response)
          id = record_id(request)
          moved = folder_at(request).bind { move_note_folder.call(id, parent_id: it) }

          case moved
            in Success(_)
              moved_toast(response, request.params[:path])
              response.redirect_to(back(request))
            in Failure[:invalid, errors] then refused(request, response, errors)
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end
