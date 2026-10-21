# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Describe < FileAction
          DESCRIBED = "memories_page.toasts.described"

          include Deps[describe_memory_file: "agents.operations.describe_memory_file"]

          def handle(request, response)
            values = Blog::Types::Fields[request.params[:memory_file]].slice(:description)
            result = describe_memory_file.call(record_id(request), { **values, **OWNER })

            written(request, response, result, DESCRIBED, { name: :describe, values: })
          end
        end
      end
    end
  end
end
