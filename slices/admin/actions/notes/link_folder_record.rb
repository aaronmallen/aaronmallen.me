# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class LinkFolderRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["note_folder"]

        include Deps[build_notes_page: "operations.build_notes_page", index_view: "ui.views.notes.index"]

        private

        def record_path(_request, id) = routes.path(:admin_note_folder, id:)

        def render_refused(request, response, id, errors)
          page = build_notes_page.call(folder_id: id, records: records_query(request, errors))
          halt :not_found unless page[:folder]

          unprocessable(response, index_view, **page)
        end
      end
    end
  end
end
