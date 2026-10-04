# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["journal_entry"]

        include RecordLinking
        include Deps[
          index_view: "ui.views.journal.index",
          link_records: "links.operations.link_records",
          open_journal_entry: "operations.open_journal_entry",
          summarize_journal: "operations.summarize_journal",
        ]

        def handle(request, response) = link(request, response)

        private

        def day(request) = Blog::Types::DateParam[request.params[:to]]

        def record_path(request, id) = routes.path(:admin_journal, to: day(request), edit: id)

        def render_refused(request, response, id, errors)
          to = day(request)
          journal = summarize_journal.call(to:)
          editing = open_journal_entry.call(journal[:days], id, records: records_query(request, errors))
          halt 404 unless editing

          response.render(index_view, **journal, editing:)
        end
      end
    end
  end
end
