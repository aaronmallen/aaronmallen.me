# frozen_string_literal: true

module MCP
  module Tools
    class UpdateJournalEntry < Base
      UNSAVED = "could not save the journal entry"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          body: { type: "string", description: "the new entry, in markdown" },
          id: { type: "integer" },
          tags: JournalEntries::TAGS,
        },
        required: ["id"],
      }.freeze

      description "Edit one journal entry's body or tags. A field you leave out keeps what it has, and an empty " \
                  "tags list clears them. Its date and time stay as they are"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:, body: nil, tags: nil)
          entry = journal_entry_by_id(server_context).call(id)
          return missing(id) if entry.nil?

          params = { body: body || entry.body, tags: JournalEntries.tag_list(tags || entry.tags.map(&:name)) }
          saved(id, update_journal_entry(server_context).call(id, params))
        end

        private

        def missing(id) = refuse("no journal entry has the ID #{id}")

        def saved(id, result)
          case result
          in Success(entry) then answer(JournalEntries.fields(entry))
          in Failure[:invalid, errors] then refuse(JournalEntries.complaint(errors))
          in Failure(:not_found) then missing(id)
          else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
