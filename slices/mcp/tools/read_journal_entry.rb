# frozen_string_literal: true

module MCP
  module Tools
    class ReadJournalEntry < Base
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Read one journal entry: its date, time, body and tags"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          entry = journal_entry_by_id(server_context).call(id)
          return refuse("no journal entry has the ID #{id}") if entry.nil?

          answer(JournalEntries.fields(entry))
        end
      end
    end
  end
end
