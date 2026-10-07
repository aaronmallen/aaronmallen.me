# frozen_string_literal: true

module MCP
  module Tools
    class WakeInboxRow < Base
      description "Wake one snoozed inbox row now, as the Wake now button on the admin's Inbox screen does, so it " \
                  "returns to the top of the inbox. Name the row by its kind and the id that kind's tools take. A " \
                  "row that is not snoozed is refused. The row comes back as list_inbox gives it, with the text " \
                  "from someone else marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE

      class << self
        private

        def answered(row) = Untrusted.inbox(row)
      end
    end
  end
end
