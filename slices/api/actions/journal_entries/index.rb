# frozen_string_literal: true

module API
  module Actions
    module JournalEntries
      class Index < Action
        include Deps[endpoint: "endpoints.list_journal_entries"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :from, :to)))
      end
    end
  end
end
