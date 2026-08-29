# frozen_string_literal: true

module MCP
  module Tools
    class CreateJournalEntry < Base
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

      description "Write a new journal entry, stamped with the time now. It lands on today unless entry_date " \
                  "names an earlier day, and a day after today is refused"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(body:, server_context:, entry_date: nil, tags: nil)
          params = { body:, entry_date:, tags: JournalEntries.tag_list(tags) }

          case save_journal_entry(server_context).call(params)
          in Success(entry) then answer(JournalEntries.fields(entry))
          in Failure[:invalid, errors] then refuse(JournalEntries.complaint(errors))
          else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
