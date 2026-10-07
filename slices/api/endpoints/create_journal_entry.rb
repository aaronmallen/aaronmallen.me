# frozen_string_literal: true

module API
  module Endpoints
    class CreateJournalEntry < Endpoint
      UNSAVED = "could not save the journal entry"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          body: { type: "string", description: "the entry, in markdown" },
          entry_date: { type: "string", description: "the day it belongs to, as YYYY-MM-DD; today when left out" },
          tags: JournalEntries::TAGS,
        },
        required: ["body"],
      }.freeze

      REPLY = Serializers::JournalEntry.reference

      include Deps[save_journal_entry: "record.operations.save_journal_entry"]

      def handle(body:, entry_date: nil, tags: nil)
        params = { body:, entry_date:, tags: Wording.tag_list(tags) }

        case save_journal_entry.call(params)
          in Success(entry) then Success(serialized(Serializers::JournalEntry, entry))
          in Failure[:invalid, errors] then invalid(Wording.complaints(errors, JournalEntries::COMPLAINTS, named: true))
          else failed(UNSAVED)
        end
      end
    end
  end
end
