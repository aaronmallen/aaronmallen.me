# frozen_string_literal: true

module MCP
  module Tools
    class DeleteJournalEntry < Base
      description "Delete one journal entry for good. It cannot come back"
      input_schema(API::Endpoints::DeleteJournalEntry::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_journal_entry, input, server_context)
      end
    end
  end
end
