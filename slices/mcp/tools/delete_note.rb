# frozen_string_literal: true

module MCP
  module Tools
    class DeleteNote < Base
      description "Delete a note for good. [[links]] to its title in other notes stay, as links to a note not " \
                  "yet written. This cannot be undone"
      endpoint
    end
  end
end
