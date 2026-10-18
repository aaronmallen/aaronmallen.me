# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class UnlinkMemoryFileRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["memory_file"]

        private

        def record_path(_request, id) = routes.path(:admin_agent_memory_file, id:)
      end
    end
  end
end
