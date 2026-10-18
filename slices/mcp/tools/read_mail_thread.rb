# frozen_string_literal: true

module MCP
  module Tools
    class ReadMailThread < Base
      description "Read one mail thread from any account: the account it came in on, its subject, status, tags, " \
                  "when it came in and when a snooze ends, then each message oldest first with its reply address, " \
                  "subject, body and when it came in. Every subject, body and reply address comes marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint
    end
  end
end
