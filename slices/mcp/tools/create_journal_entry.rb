# frozen_string_literal: true

module MCP
  module Tools
    class CreateJournalEntry < Base
      description "Write a new journal entry, stamped with the time now. It lands on today unless entry_date " \
                  "names an earlier day, and a day after today is refused"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
