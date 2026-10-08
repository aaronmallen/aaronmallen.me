# frozen_string_literal: true

module MCP
  module Tools
    class ListJournalEntries < Base
      description "List the journal entries in a date range, each with its ID, date, time, whole body and tags. " \
                  "Give tag to keep only the entries that carry it. stats gives the whole journal's entries and " \
                  "words, and on how many of the last days an entry was written, as the admin's journal shows. " \
                  "#{Blog::Helpers::DayWindow::PAGING_NOTE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
