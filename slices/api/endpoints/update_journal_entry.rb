# frozen_string_literal: true

module API
  module Endpoints
    class UpdateJournalEntry < Endpoint
      UNSAVED = "could not save the journal entry"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          body: { type: "string", description: "the new entry, in markdown" },
          id: JournalEntries::ID,
          tags: JournalEntries::TAGS,
        },
        required: ["id"],
      }.freeze

      REPLY = Serializers::JournalEntry.reference

      include Deps[
        journal_entry_by_id: "record.queries.journal_entry_by_id",
        update_journal_entry: "record.operations.update_journal_entry",
      ]

      def handle(id:, body: nil, tags: nil)
        entry = journal_entry_by_id.call(id)
        return not_found(Wording.missing("journal entry", id)) if entry.nil?

        params = { body: body || entry.body, tags: Wording.tag_list(tags || entry.tags.map(&:name)) }
        saved(id, update_journal_entry.call(id, params))
      end

      private

      def saved(id, result)
        case result
        in Success(entry) then Success(serialized(Serializers::JournalEntry, entry))
        in Failure[:invalid, errors] then invalid(Wording.complaints(errors, JournalEntries::COMPLAINTS, named: true))
        in Failure(:not_found) then not_found(Wording.missing("journal entry", id))
        else failed(UNSAVED)
        end
      end
    end
  end
end
