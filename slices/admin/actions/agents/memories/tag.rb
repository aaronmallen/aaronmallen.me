# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Tag < TagAction
          DONE = "tagged"

          include Deps[tag_memory_file: "agents.operations.tag_memory_file"]

          private

          def list_path = routes.path(:admin_memory_files)

          def retag(id, tag) = tag_memory_file.call(id, tag)
        end
      end
    end
  end
end
