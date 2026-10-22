# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["note"]

        include Deps[
          build_notes_page: "operations.build_notes_page",
          note_queries: "notes.repos.note_queries",
          index_view: "ui.views.notes.index",
        ]

        private

        def record_path(_request, id) = routes.path(:admin_note, id:)

        def render_refused(request, response, id, errors)
          note = note_queries.by_id(id) || halt(:not_found)

          unprocessable(response, index_view, **build_notes_page.call(note:, records: records_query(request, errors)))
        end
      end
    end
  end
end
