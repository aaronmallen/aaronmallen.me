# frozen_string_literal: true

module API
  module Endpoints
    class ReadShare < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::Share.reference

      include Deps[share_queries: "shares.repos.share_queries"]

      def handle(id:)
        share = share_queries.find(id)
        return missing("share", id) unless share

        Success(serialized(Serializers::Share, share, settings:))
      end
    end
  end
end
