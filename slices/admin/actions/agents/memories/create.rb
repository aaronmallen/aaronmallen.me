# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Create < Action
          CREATED = "memories_page.toasts.created"

          include Deps[
            build_memories_page: "operations.build_memories_page",
            create_memory_file: "agents.operations.create_memory_file",
            memories_view: "ui.views.agents.memories",
          ]

          def handle(request, response)
            values = Blog::Types::Fields[request.params[:memory_file]].slice(:path, :description, :scope)

            fields = { **values.slice(:path, :description), **Helpers::MemoryScope.fields(values[:scope]) }

            case create_memory_file.call(fields)
              in Success(file) then toast_back(response, CREATED, routes.path(:admin_memory_file, id: file.id))
              in Failure[:invalid, errors] then refuse(response, values, errors)
            end
          end

          private

          def refuse(response, values, errors)
            unprocessable(response, memories_view, **build_memories_page.call(values:, errors: scoped(errors)))
          end

          def scoped(errors) = errors.transform_keys { Helpers::MemoryScope::TARGETS.value?(it) ? :scope : it }
        end
      end
    end
  end
end
