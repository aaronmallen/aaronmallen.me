# frozen_string_literal: true

module API
  module Endpoints
    class ReadShareGroup < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::ShareGroup.reference

      include Deps[share_group_queries: "shares.repos.share_group_queries"]

      def handle(id:)
        group = share_group_queries.find(id)
        return not_found(Helpers::Wording.missing("share group", id)) unless group

        Success(serialized(Serializers::ShareGroup, group, origin: share_origin))
      end
    end
  end
end
