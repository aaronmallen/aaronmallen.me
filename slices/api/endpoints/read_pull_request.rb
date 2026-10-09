# frozen_string_literal: true

module API
  module Endpoints
    class ReadPullRequest < Endpoint
      KIND = Blog::Types::RecordKind["pull_request"]
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::PullRequest::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        pull_request_queries: "record.repos.pull_request_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def handle(id:)
        pull_request = pull_request_queries.by_id(id)
        return not_found(Helpers::Wording.missing("pull request", id)) if pull_request.nil?

        Success(serialized(Serializers::PullRequest, pull_request).merge(record_links: linked(KIND, pull_request.id)))
      end
    end
  end
end
