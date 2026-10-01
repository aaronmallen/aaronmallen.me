# frozen_string_literal: true

module API
  module Actions
    module JournalEntries
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_journal_entry"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
