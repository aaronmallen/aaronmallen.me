# frozen_string_literal: true

module API
  module Endpoints
    class UpdateShareGroupFile < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, file_id: Helpers::Schema::ID, filename: UpdateShare::FILENAME },
        required: %w[id file_id filename],
      }.freeze

      REPLY = Serializers::ShareGroup.reference

      include Deps[
        rename_share_file: "shares.operations.rename_share_file",
        share_group_queries: "shares.repos.share_group_queries",
      ]

      def handle(id:, file_id:, filename:)
        group = share_group_queries.find(id)
        return missing("share group", id) unless group
        return not_found("share group #{id} has no file with the ID #{file_id}") unless held?(group, file_id)

        case rename_share_file.call(file_id, { filename: })
          in Success(_) then Success(reply(id))
          in Failure[:invalid, errors] then rejected(errors, {})
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      private

      def held?(group, file_id) = group.share_group_files.any? { it.id == file_id }

      def reply(id) = serialized(Serializers::ShareGroup, share_group_queries.find(id), settings:)
    end
  end
end
