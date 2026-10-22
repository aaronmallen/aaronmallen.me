# frozen_string_literal: true

module API
  module Endpoints
    class RemoveShareGroupFile < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, file_id: Helpers::Schema::ID },
        required: %w[id file_id],
      }.freeze

      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, file_id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN },
      ).freeze

      UNAVAILABLE = true

      include Deps[
        remove_share_group_file: "shares.operations.remove_share_group_file",
        share_group_queries: "shares.repos.share_group_queries",
      ]

      def handle(id:, file_id:)
        return missing("share group", id) unless share_group_queries.find(id)

        case remove_share_group_file.call(id, file_id)
          in Success(_) then Success(id:, file_id:, deleted: true)
          in Failure(:not_found) then not_found("share group #{id} has no file with the ID #{file_id}")
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(Helpers::Upload::STORE_DOWN))
        end
      end
    end
  end
end
