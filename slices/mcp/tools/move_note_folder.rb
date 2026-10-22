# frozen_string_literal: true

module MCP
  module Tools
    class MoveNoteFolder < Base
      description "Move a note folder into another, or to the top level with a null parent_id. " \
                  "A folder cannot move inside itself or a folder within it"
      endpoint
    end
  end
end
