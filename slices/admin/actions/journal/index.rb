# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Index < Action
        include Deps[
          open_journal_entry: "operations.open_journal_entry",
          summarize_journal: "operations.summarize_journal",
        ]

        def handle(request, response)
          params = request.params
          search = Blog::Types::Text[params[:q]]
          to = Blog::Types::DateParam[params[:to]]
          writing = Blog::Types::Checkbox[params[:write]]
          journal = summarize_journal.call(search:, to:, filters: params)

          response.render(view, **journal, editing: editing(params, journal[:days]), search:, writing:)
        end

        private

        def editing(params, days)
          open_journal_entry.call(days, Blog::Types::IdParam[params[:edit]], records: { query: params[:record_q] })
        end
      end
    end
  end
end
