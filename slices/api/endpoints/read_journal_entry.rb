# frozen_string_literal: true

module API
  module Endpoints
    class ReadJournalEntry < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: JournalEntries::ID }, required: ["id"] }.freeze

      include Deps[journal_entry_by_id: "record.queries.journal_entry_by_id"]

      def handle(id:)
        entry = journal_entry_by_id.call(id)
        return not_found(JournalEntries.missing(id)) if entry.nil?

        Success(serialized(Serializers::JournalEntry, entry))
      end
    end
  end
end
