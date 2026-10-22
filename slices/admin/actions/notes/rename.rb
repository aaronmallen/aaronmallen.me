# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Rename < Action
        RENAMED = "notes_page.toasts.renamed"

        include Place
        include Deps[rename_note: "notes.operations.rename_note"]

        def handle(request, response)
          renamed = rename_note.call(record_id(request), title: request.params[:title])

          settle(response, renamed, RENAMED, back(request)) { refused(request, response, it) }
        end
      end
    end
  end
end
