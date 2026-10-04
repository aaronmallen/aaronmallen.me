# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Update < Action
        KIND = Blog::Types::RecordKind["journal_entry"]
        UPDATED = "journal_page.toasts.updated"

        include Deps[
          index_view: "ui.views.journal.index",
          list_record_links: "operations.list_record_links",
          summarize_journal: "operations.summarize_journal",
          update_journal_entry: "record.operations.update_journal_entry",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:entry]]

          case update_journal_entry.call(id, params)
          in Success(_) then updated(response)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, id, params, errors)
          else halt 500
          end
        end

        private

        def editing(id, params, errors)
          {
            id:, body: Blog::Types::Text[params[:body]], tags: Blog::Types::Text[params[:tags]], errors:,
            records: list_record_links.call(KIND, id),
          }
        end

        def invalid(response, id, params, errors)
          response.status = 422
          response.render(index_view, **summarize_journal.call, editing: editing(id, params, errors))
        end

        def updated(response)
          toast(response, UPDATED)
          response.redirect_to(routes.path(:admin_journal))
        end
      end
    end
  end
end
