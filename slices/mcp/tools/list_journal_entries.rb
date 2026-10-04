# frozen_string_literal: true

module MCP
  module Tools
    class ListJournalEntries < Base
      description "List the journal entries in a date range, each with its ID, date, time, whole body and tags. " \
                  "#{Blog::DayWindow::PAGING_NOTE}"
      input_schema(API::Endpoints::ListJournalEntries::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_journal_entries, input, server_context)
      end
    end
  end
end
