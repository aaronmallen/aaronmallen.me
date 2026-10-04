# frozen_string_literal: true

module MCP
  module Tools
    class ReadJournalEntry < Base
      description "Read one journal entry: its date, time, body, tags and the records linked to it, grouped by kind"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
