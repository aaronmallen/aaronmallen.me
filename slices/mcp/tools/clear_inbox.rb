# frozen_string_literal: true

module MCP
  module Tools
    class ClearInbox < Base
      description "Clear inbox rows by the ids list_inbox gives them, as the admin's Mark All As Seen button does: " \
                  "it marks issues seen, messages read, and webmentions seen but still pending. One that fails " \
                  "clears none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
