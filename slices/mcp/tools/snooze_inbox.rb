# frozen_string_literal: true

module MCP
  module Tools
    class SnoozeInbox < Base
      description "Snooze inbox rows until a time by the ids list_inbox gives them, as the admin's Snooze All " \
                  "button does. Each row leaves the inbox and comes back at the top when the time passes. One " \
                  "that fails snoozes none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
