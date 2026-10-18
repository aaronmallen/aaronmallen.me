# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class UnlinkRecord < UnlinkRecordAction
          KIND = Blog::Types::RecordKind["artifact"]

          private

          def record_path(_request, id) = routes.path(:admin_artifact, id:)
        end
      end
    end
  end
end
