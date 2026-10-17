# frozen_string_literal: true

module API
  module Endpoints
    class UpdateShare < Endpoint
      FILENAME = { type: "string", description: "the name a download saves as; the link stays the same" }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, filename: FILENAME },
        required: %w[id filename],
      }.freeze

      REPLY = Serializers::Share.reference

      include Deps[
        rename_share_file: "shares.operations.rename_share_file", share_queries: "shares.repos.share_queries",
      ]

      def handle(id:, filename:)
        return missing("share", id) unless share_queries.find(id)

        case rename_share_file.call(id, { filename: })
          in Success(_) then Success(serialized(Serializers::Share, share_queries.find(id), settings:))
          in Failure[:invalid, errors] then rejected(errors, {})
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
