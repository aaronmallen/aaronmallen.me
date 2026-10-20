# frozen_string_literal: true

module MCP
  module Tools
    class RemoveMemoryFact < Base
      description "Remove a fact so reads and searches skip it, naming the file and fact by the IDs " \
                  "read_memory_file or search_memory gives. Its text stays in the history, so reverting the removal " \
                  "brings it back. Name yourself with agent and model slugs"
      endpoint
    end
  end
end
