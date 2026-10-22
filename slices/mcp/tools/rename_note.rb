# frozen_string_literal: true

module MCP
  module Tools
    class RenameNote < Base
      description "Retitle a note. Every [[link]] to the old title in other notes follows it to the new one, " \
                  "and relinked counts the notes rewritten. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
