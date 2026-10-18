# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class RevertMemoryEvent < MemoryFileAction
        REVERTED = "memories_page.toasts.reverted"

        include Deps[revert_memory_event: "agents.operations.revert_memory_event"]

        def handle(request, response)
          result = revert_memory_event.call(record_id(request), record_id(request, :event_id), OWNER)

          written(request, response, result, REVERTED)
        end
      end
    end
  end
end
