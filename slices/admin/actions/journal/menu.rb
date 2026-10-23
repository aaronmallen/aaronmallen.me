# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Menu < Action
        RECORD = Blog::Types::RecordKind["journal_entry"]

        include Deps[
          journal_entry_queries: "record.repos.journal_entry_queries",
          tag_queries: "tags.repos.tag_queries",
        ]

        def handle(request, response)
          entry = journal_entry_queries.by_id(record_id(request)) || halt(:not_found)

          response.render(view, entry:, tags: tag_queries.choices_for(RECORD, entry.id), return_to: back_here(request))
        end
      end
    end
  end
end
