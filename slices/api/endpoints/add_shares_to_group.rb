# frozen_string_literal: true

module API
  module Endpoints
    class AddSharesToGroup < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          ids: Helpers::Schema.ids("single shares").merge(
            description: "the single shares to move into the group; one that fails moves none",
          ),
        },
        required: %w[id ids],
      }.freeze

      REPLY = Serializers::ShareGroup.reference

      include Deps[
        add_shares_to_group: "shares.operations.add_shares_to_group",
        share_group_queries: "shares.repos.share_group_queries",
      ]

      def handle(id:, ids:)
        return missing("share group", id) unless share_group_queries.find(id)

        case add_shares_to_group.call(id, ids)
          in Success(group) then Success(serialized(Serializers::ShareGroup, group, origin: share_origin))
          in Failure(:not_found) then invalid(ids: [GroupShares::NOT_SINGLE])
          in Failure[:invalid, errors] then rejected(errors, {})
        end
      end
    end
  end
end
