# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class AddFact < FileAction
          ADDED = "memories_page.toasts.added"

          include Deps[add_memory_fact: "agents.operations.add_memory_fact"]

          def handle(request, response)
            values = fact_fields(request)
            result = add_memory_fact.call(record_id(request), { **values, **OWNER })

            written(request, response, result, ADDED, { name: :add, values: })
          end
        end
      end
    end
  end
end
