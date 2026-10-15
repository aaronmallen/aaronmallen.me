# frozen_string_literal: true

module API
  module Endpoints
    class GroupShares < Endpoint
      NOT_SINGLE = "names a share that is not there or already sits in a group"
      TOO_FEW = "needs two or more single shares"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          ids: Helpers::Schema.ids("single shares").merge(
            minItems: 2, description: "the single shares to group under one new link; one that fails groups none",
          ),
        },
        required: %w[ids],
      }.freeze

      REPLY = Serializers::ShareGroup.reference

      include Deps[group_shares: "shares.operations.group_shares"]

      def handle(ids:)
        case group_shares.call(ids)
          in Success(group) then Success(serialized(Serializers::ShareGroup, group, origin: share_origin))
          in Failure(:not_found) then invalid(ids: [NOT_SINGLE])
          in Failure[:invalid, errors] then rejected(errors, { ids: { "too_few" => TOO_FEW } })
        end
      end
    end
  end
end
