# frozen_string_literal: true

module MCP
  module Tools
    class ReadJournalEntry < Base
      description "Read one journal entry: its date, time, body and tags"
      input_schema(API::Endpoints::ReadJournalEntry::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_journal_entry, input, server_context)
      end
    end
  end
end
