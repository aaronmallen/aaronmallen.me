# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Destroy < Action
          DELETED = "memories_page.toasts.deleted"

          include Deps[delete_memory_file: "agents.operations.delete_memory_file"]

          def handle(request, response)
            settle(response, delete_memory_file.call(record_id(request)), DELETED, routes.path(:admin_memory_files))
          end
        end
      end
    end
  end
end
