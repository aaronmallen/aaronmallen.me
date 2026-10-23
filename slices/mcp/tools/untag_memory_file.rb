# frozen_string_literal: true

module MCP
  module Tools
    class UntagMemoryFile < Base
      description "Take one tag off a memory file. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
