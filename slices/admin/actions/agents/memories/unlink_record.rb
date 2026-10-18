# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class UnlinkRecord < UnlinkRecordAction
          KIND = Blog::Types::RecordKind["memory_file"]

          private

          def record_path(_request, id) = routes.path(:admin_memory_file, id:)
        end
      end
    end
  end
end
