# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class ShowFolder < Action
        include Deps[build_notes_page: "operations.build_notes_page", view: "ui.views.notes.index"]

        def handle(request, response)
          page = build_notes_page.call(folder_id: record_id(request), records: { query: request.params[:record_q] })
          not_found(response) unless page[:folder]

          response.render(view, **page)
        end
      end
    end
  end
end
