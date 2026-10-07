# frozen_string_literal: true

module MCP
  module Tools
    class SnoozeInboxRow < Base
      description "Snooze one inbox row until a time, as the inbox's Snooze dialog does. Name the row by the kind " \
                  "and id list_inbox gives it. The row leaves the inbox and comes back at the top when the time " \
                  "passes, with its seen, read or pending state kept"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
