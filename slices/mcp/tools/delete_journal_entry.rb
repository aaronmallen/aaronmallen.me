# frozen_string_literal: true

module MCP
  module Tools
    class DeleteJournalEntry < Base
      description "Delete one journal entry for good. It cannot come back"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
