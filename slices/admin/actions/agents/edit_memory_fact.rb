# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class EditMemoryFact < MemoryFileAction
        SAVED = "memories_page.toasts.saved"

        include Deps[edit_memory_fact: "agents.operations.edit_memory_fact"]

        def handle(request, response)
          id = record_id(request, :fact_id)
          values = fact_fields(request)
          result = edit_memory_fact.call(record_id(request), id, { **values, **OWNER })

          written(request, response, result, SAVED, { name: :edit, id:, values: })
        end
      end
    end
  end
end
