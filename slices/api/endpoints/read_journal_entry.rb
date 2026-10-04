# frozen_string_literal: true

module API
  module Endpoints
    class ReadJournalEntry < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: JournalEntries::ID }, required: ["id"] }.freeze
      KIND = "journal_entry"
      REPLY = Schema.widen(Serializers::JournalEntry::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        journal_entry_by_id: "record.queries.journal_entry_by_id",
        record_links: "links.queries.record_links",
      ]

      def handle(id:)
        entry = journal_entry_by_id.call(id)
        return not_found(JournalEntries.missing(id)) if entry.nil?

        Success(serialized(Serializers::JournalEntry, entry).merge(record_links: linked(KIND, id)))
      end
    end
  end
end
