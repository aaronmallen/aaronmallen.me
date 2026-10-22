# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Rename < Action
        RELINKED = "notes_page.toasts.relinked"

        include Place
        include Deps[note_queries: "notes.repos.note_queries", rename_note: "notes.operations.rename_note"]

        def handle(request, response)
          id = record_id(request)
          title = request.params[:title]
          count = note_queries.relinks(id, title)

          case rename_note.call(id, { title: })
            in Success(_)
              toast(response, RELINKED, count:)
              response.redirect_to(back(request))
            in Failure[:invalid, errors] then refused(request, response, errors)
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end
