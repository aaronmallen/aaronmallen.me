# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["journal_entry"]

        include Deps[
          index_view: "ui.views.journal.index",
          open_journal_entry: "operations.open_journal_entry",
          summarize_journal: "operations.summarize_journal",
        ]

        private

        def day(request) = Blog::Types::DateParam[request.params[:to]]

        def record_path(request, id) = routes.path(:admin_journal, to: day(request), edit: id)

        def render_refused(request, response, id, errors)
          to = day(request)
          journal = summarize_journal.call(to:)
          editing = open_journal_entry.call(journal[:days], id, records: records_query(request, errors))
          halt :not_found unless editing

          unprocessable(response, index_view, **journal, editing:, to:)
        end
      end
    end
  end
end
