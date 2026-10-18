# frozen_string_literal: true

module MCP
  module Tools
    class RemoveMemoryFact < Base
      description "Remove a fact so it stops loading, naming the file and fact by the IDs the loaded markdown " \
                  "gives as file <id> and [fact <id>]. Its text stays in the history, so reverting the removal " \
                  "brings it back. Name yourself with agent and model slugs"
      endpoint
    end
  end
end
