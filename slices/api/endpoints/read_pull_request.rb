# frozen_string_literal: true

module API
  module Endpoints
    class ReadPullRequest < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::PullRequest::SCHEMA

      include Deps[pull_request_queries: "record.repos.pull_request_queries"]

      def handle(id:)
        pull_request = pull_request_queries.by_id(id)
        return not_found(Helpers::Wording.missing("pull request", id)) if pull_request.nil?

        Success(serialized(Serializers::PullRequest, pull_request))
      end
    end
  end
end
