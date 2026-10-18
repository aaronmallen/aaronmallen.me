# frozen_string_literal: true

module API
  module Endpoints
    class UpdateShareGroup < Endpoint
      COMPLAINTS = Blog::Constants::EMPTY_HASH
      CONTRACTS = [::Shares::Contracts::ShareContract].freeze
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          name: Helpers::Schema.nullable(Helpers::Schema::STRING).merge(
            description: "titles the group's page and names its zip; null or blank falls back to the code",
          ),
        },
        required: %w[id name],
      }.freeze

      REPLY = Serializers::ShareGroup.reference

      include Deps[name_share_group: "shares.operations.name_share_group"]

      def handle(id:, name:)
        case name_share_group.call(id, { name: })
          in Success(group) then Success(serialized(Serializers::ShareGroup, group, settings:))
          in Failure(:not_found) then missing("share group", id)
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
        end
      end
    end
  end
end
