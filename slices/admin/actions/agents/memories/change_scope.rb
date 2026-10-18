# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class ChangeScope < FileAction
          SCOPED = "memories_page.toasts.scoped"

          include Deps[change_memory_scope: "agents.operations.change_memory_scope"]

          def handle(request, response)
            key = Blog::Types::Fields[request.params[:memory_file]][:scope]
            result = change_memory_scope.call(record_id(request), { **Helpers::MemoryScope.fields(key), **OWNER })

            written(request, response, result.alt_map { scoped(it) }, SCOPED, { name: :scope, values: { scope: key } })
          end

          private

          def scoped(failure)
            failure in [:invalid, errors] or return failure

            [:invalid, errors.transform_keys { Helpers::MemoryScope::TARGETS.value?(it) ? :scope : it }]
          end
        end
      end
    end
  end
end
