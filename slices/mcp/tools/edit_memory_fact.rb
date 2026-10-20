# frozen_string_literal: true

module MCP
  module Tools
    class EditMemoryFact < Base
      description "Change a fact's type or text, naming the file and fact by the IDs read_memory_file or " \
                  "search_memory gives. The history keeps the old one, so the change can be reverted. Name " \
                  "yourself with agent and model slugs"
      endpoint
    end
  end
end
