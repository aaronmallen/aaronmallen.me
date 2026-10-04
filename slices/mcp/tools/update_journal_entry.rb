# frozen_string_literal: true

module MCP
  module Tools
    class UpdateJournalEntry < Base
      description "Edit one journal entry's body or tags. A field you leave out keeps what it has, and an empty " \
                  "tags list clears them. Its date and time stay as they are"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
