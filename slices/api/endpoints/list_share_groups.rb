# frozen_string_literal: true

module API
  module Endpoints
    class ListShareGroups < Endpoint
      SCHEMA = { additionalProperties: false, properties: { page: Helpers::Paging::PAGE } }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, share_groups: Helpers::Schema.list(Serializers::ShareGroup.reference) },
      ).freeze

      include Deps[share_group_queries: "shares.repos.share_group_queries"]

      def handle(page: 1)
        groups = share_group_queries.page(page_of(page))

        Success(
          count: share_group_queries.count,
          share_groups: serialized(Serializers::ShareGroup, groups.rows, settings:),
          **Helpers::Paging.fields(groups),
        )
      end
    end
  end
end
