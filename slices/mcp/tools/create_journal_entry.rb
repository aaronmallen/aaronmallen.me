# frozen_string_literal: true

module MCP
  module Tools
    class CreateJournalEntry < Base
      description "Write a new journal entry, stamped with the time now. It lands on today unless entry_date " \
                  "names an earlier day, and a day after today is refused"
      input_schema(API::Endpoints::CreateJournalEntry::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:create_journal_entry, input, server_context)
      end
    end
  end
end
