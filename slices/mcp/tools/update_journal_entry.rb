# frozen_string_literal: true

module MCP
  module Tools
    class UpdateJournalEntry < Base
      description "Edit one journal entry's body or tags. A field you leave out keeps what it has, and an empty " \
                  "tags list clears them. Its date and time stay as they are"
      input_schema(API::Endpoints::UpdateJournalEntry::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:update_journal_entry, input, server_context)
      end
    end
  end
end
