# frozen_string_literal: true

module MCP
  module Tools
    class AddMemoryFact < Base
      description "Add a fact to a memory file: a preference, convention, gotcha or context. It loads into every " \
                  "later session at once. Name yourself with agent and model slugs"
      endpoint
    end
  end
end
