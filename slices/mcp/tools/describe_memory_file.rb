# frozen_string_literal: true

module MCP
  module Tools
    class DescribeMemoryFile < Base
      description "Set or change a memory file's description: one line on what it covers and when to read it. " \
                  "Name yourself with agent and model slugs, such as claude-code and claude-opus-5-5"
      endpoint
    end
  end
end
