# frozen_string_literal: true

module API
  module Endpoints
    class ReadJournalEntry < Endpoint
      SCHEMA = Schema.by_id
      KIND = "journal_entry"
      REPLY = Schema.widen(Serializers::JournalEntry::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        journal_entry_queries: "record.repos.journal_entry_queries",
        record_links: "links.queries.record_links",
      ]

      def handle(id:)
        entry = journal_entry_queries.by_id(id)
        return not_found(Wording.missing("journal entry", id)) if entry.nil?

        Success(serialized(Serializers::JournalEntry, entry).merge(record_links: linked(KIND, id)))
      end
    end
  end
end
