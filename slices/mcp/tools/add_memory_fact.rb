# frozen_string_literal: true

module MCP
  module Tools
    class AddMemoryFact < Base
      description "Add a fact to a memory file: a preference, convention, gotcha or context. read_memory_file and " \
                  "search_memory find it at once. Name yourself with agent and model slugs"
      endpoint
    end
  end
end
