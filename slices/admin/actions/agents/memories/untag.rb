# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Untag < TagAction
          DONE = "untagged"

          include Deps[untag_memory_file: "agents.operations.untag_memory_file"]

          private

          def list_path = routes.path(:admin_memory_files)

          def retag(id, tag) = untag_memory_file.call(id, tag)
        end
      end
    end
  end
end
