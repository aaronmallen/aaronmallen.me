# frozen_string_literal: true

module MCP
  module Tools
    class ReadMemoryFile < Base
      description "Read one memory file: its path, description, scope, tags and facts. Facts come whole. Pass " \
                  "history true to add its history of changes, newest first, with the agent and model that made " \
                  "each, or null for the owner; revert_memory_event takes an entry ID from it. History comes a " \
                  "page at a time. When more remains, partial comes back true and next_page holds the page to " \
                  "send for older changes. Give session_id to record the file as read by that session; an ended " \
                  "session still allows the read but records nothing. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
