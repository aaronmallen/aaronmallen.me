# frozen_string_literal: true

module MCP
  module Tools
    class RemoveNoteFolder < Base
      description "Remove a note folder for good. Its notes and the folders in it move up to " \
                  "the folder it sat in. This cannot be undone"
      endpoint
    end
  end
end
