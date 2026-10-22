# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Notes
      class Update < Action
        JSON_TYPE = "application/json"
        SAVED = "notes_page.toasts.saved"

        include Deps[
          build_notes_page: "operations.build_notes_page",
          edit_note: "notes.operations.edit_note",
          note_queries: "notes.repos.note_queries",
          index_view: "ui.views.notes.index",
        ]

        config.formats.accept :html, :json

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:note]]
          result = edit_note.call(id, params.slice(:title, :body, :tags, :version))
          return answer(response, result) if request.get_header("HTTP_ACCEPT").to_s.start_with?(JSON_TYPE)

          settle(response, result, SAVED, routes.path(:admin_note, id:, edit: 1)) do |errors|
            refuse(response, id, params, errors)
          end
        end

        private

        def answer(response, result)
          response.format = :json
          case result
            in Success(note) then response.body = JSON.generate({ version: note.version, title: note.title })
            in Failure[:invalid, errors]
              response.status = :unprocessable_content
              response.body = JSON.generate({ errors: errors.transform_values { Array(it).first } })
            in Failure(:not_found) then halt :not_found
          end
        end

        def refuse(response, id, params, errors)
          note = note_queries.by_id(id) || halt(:not_found)
          page = build_notes_page.call(note:)

          unprocessable(response, index_view, **page, editing: true, errors:, values: params)
        end
      end
    end
  end
end
