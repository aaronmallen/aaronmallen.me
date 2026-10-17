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
          to = Blog::Types::DateParam[request.params[:to]]
          search = Blog::Types::TrimmedText[request.params[:q]]

          result = update_journal_entry.call(id, params)

          settle(response, result, UPDATED, back(to, search)) do |errors|
            invalid(request, response, editing(id, params, errors), to:, search:)
          end
        end

        private

        def back(to, search) = routes.path(:admin_journal, **{ to:, q: (search unless search.empty?) }.compact)

        def editing(id, params, errors)
          {
            id:, body: Blog::Types::Text[params[:body]], tags: Blog::Types::Text[params[:tags]], errors:,
            records: list_record_links.call(KIND, id),
          }
        end

        def invalid(request, response, editing, to:, search:)
          journal = summarize_journal.call(search:, to:, filters: request.params)
          unprocessable(response, index_view, **journal, editing:, search:, to:)
        end
      end
    end
  end
end
