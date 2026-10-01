# frozen_string_literal: true

module API
  module Actions
    module JournalEntries
      class Create < Action
        include Deps[endpoint: "endpoints.create_journal_entry"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
