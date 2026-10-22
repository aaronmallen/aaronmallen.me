# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Notes
      class Update < Action
        JSON_TYPE = "application/json"
        RELINKED = "notes_page.toasts.relinked"
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
          relinks = relinks(id, params)
          result = edit_note.call(id, params.slice(:title, :body, :tags, :version))
          return answer(response, result, relinks) if json?(request)

          settle(response, result, SAVED, routes.path(:admin_note, id:, edit: 1)) do |errors|
            refuse(response, id, params, errors)
          end
          relinked(response, result, relinks)
        end

        private

        def answer(response, result, relinks)
          response.format = :json
          case result
            in Success(note) then response.body = JSON.generate(saved(note, relinks))
            in Failure[:invalid, errors]
              response.status = :unprocessable_content
              response.body = JSON.generate({ errors: errors.transform_values { Array(it).first } })
            in Failure(:not_found) then halt :not_found
          end
        end

        def json?(request) = request.get_header("HTTP_ACCEPT").to_s.start_with?(JSON_TYPE)

        def refuse(response, id, params, errors)
          note = note_queries.by_id(id) || halt(:not_found)
          page = build_notes_page.call(note:)

          unprocessable(response, index_view, **page, editing: true, errors:, values: params)
        end

        def relinked(response, result, count)
          toast(response, RELINKED, count:) if result.success? && count.positive?
        end

        def relinks(id, params) = params.key?(:title) ? note_queries.relinks(id, params[:title]) : 0

        def saved(note, relinks)
          relinked = i18n.t!(RELINKED, count: relinks) if relinks.positive?

          { version: note.version, title: note.title, relinked: }.compact
        end
      end
    end
  end
end
