# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Show < Action
        include Deps[
          build_notes_page: "operations.build_notes_page",
          note_queries: "notes.repos.note_queries",
          view: "ui.views.notes.index",
        ]

        def handle(request, response)
          note = note_queries.by_id(record_id(request))
          not_found(response) unless note

          params = request.params
          page = build_notes_page.call(note:, query: params[:q], records: { query: params[:record_q] })

          response.render(view, **page, editing: Blog::Types::Checkbox[params[:edit]])
        end
      end
    end
  end
end
