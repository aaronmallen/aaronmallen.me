# frozen_string_literal: true

module API
  module Endpoints
    class UngroupShareFile < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, file_id: Helpers::Schema::ID },
        required: %w[id file_id],
      }.freeze

      REPLY = Serializers::Share.reference

      include Deps[
        share_group_queries: "shares.repos.share_group_queries",
        ungroup_share_file: "shares.operations.ungroup_share_file",
      ]

      def handle(id:, file_id:)
        return missing("share group", id) unless share_group_queries.find(id)

        case ungroup_share_file.call(id, file_id)
          in Success(share) then Success(serialized(Serializers::Share, share, settings:))
          in Failure(:not_found) then not_found("share group #{id} has no file with the ID #{file_id}")
        end
      end
    end
  end
end
