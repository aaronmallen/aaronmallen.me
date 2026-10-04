# frozen_string_literal: true

module MCP
  module Tools
    class ListJournalEntries < Base
      description "List the journal entries in a date range, each with its ID, date, time, whole body and tags. " \
                  "#{Blog::DayWindow::PAGING_NOTE}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
