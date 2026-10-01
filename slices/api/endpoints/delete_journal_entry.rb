# frozen_string_literal: true

module API
  module Endpoints
    class DeleteJournalEntry < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: JournalEntries::ID }, required: ["id"] }.freeze
      REPLY = Schema.object({ id: Schema::INTEGER, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

      def handle(id:)
        case delete_journal_entry.call(id)
        in Success(_) then Success(id:, deleted: true)
        in Failure(:not_found) then not_found(JournalEntries.missing(id))
        else failed("could not delete the journal entry")
        end
      end
    end
  end
end
