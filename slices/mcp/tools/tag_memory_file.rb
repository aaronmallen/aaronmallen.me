# frozen_string_literal: true

module MCP
  module Tools
    class TagMemoryFile < Base
      description "Add one tag to a memory file. A project file takes its project's own tag of the name, made " \
                  "there when missing; a global or task file takes a private tag. The tags it already carries " \
                  "stay. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
