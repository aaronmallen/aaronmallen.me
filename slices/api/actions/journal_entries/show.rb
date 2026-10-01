# frozen_string_literal: true

module API
  module Actions
    module JournalEntries
      class Show < Action
        include Deps[endpoint: "endpoints.read_journal_entry"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
