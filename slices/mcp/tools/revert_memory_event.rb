# frozen_string_literal: true

module MCP
  module Tools
    class RevertMemoryEvent < Base
      description "Undo one add, edit or remove in a memory file's history, putting the fact back as it was before. " \
                  "It is refused when the fact changed after that entry, and names the later entry to revert first"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
