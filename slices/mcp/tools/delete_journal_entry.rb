# frozen_string_literal: true

module MCP
  module Tools
    class DeleteJournalEntry < Base
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Delete one journal entry for good. It cannot come back"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case delete_journal_entry(server_context).call(id)
          in Success(_) then answer(id:, deleted: true)
          in Failure(:not_found) then refuse("no journal entry has the ID #{id}")
          else refuse("could not delete the journal entry")
          end
        end
      end
    end
  end
end
