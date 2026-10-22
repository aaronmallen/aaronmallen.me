# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class RenameFolder < Action
        RENAMED = "notes_page.toasts.renamed"

        include Place
        include Deps[rename_note_folder: "notes.operations.rename_note_folder"]

        def handle(request, response)
          name = Blog::Types::Text[request.params[:name]].tr("/", "-")

          renamed = rename_note_folder.call(record_id(request), name:)

          settle(response, renamed, RENAMED, back(request)) { refused(request, response, it) }
        end
      end
    end
  end
end
