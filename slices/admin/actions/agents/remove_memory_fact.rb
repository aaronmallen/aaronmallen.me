# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class RemoveMemoryFact < MemoryFileAction
        REMOVED = "memories_page.toasts.removed"

        include Deps[remove_memory_fact: "agents.operations.remove_memory_fact"]

        def handle(request, response)
          result = remove_memory_fact.call(record_id(request), record_id(request, :fact_id), OWNER)

          written(request, response, result, REMOVED)
        end
      end
    end
  end
end
