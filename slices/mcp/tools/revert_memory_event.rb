# frozen_string_literal: true

module MCP
  module Tools
    class RevertMemoryEvent < Base
      description "Undo one add, edit, remove or describe in a memory file's history, putting the fact or the " \
                  "description back as it was before. It is refused when either changed after that entry, and " \
                  "names the later entry to revert first. Name yourself with agent and model slugs"
      endpoint
    end
  end
end
