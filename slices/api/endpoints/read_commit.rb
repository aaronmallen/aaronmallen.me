# frozen_string_literal: true

module API
  module Endpoints
    class ReadCommit < Endpoint
      KIND = Blog::Types::RecordKind["commit"]
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::Commit::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        commit_queries: "record.repos.commit_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def handle(id:)
        commit = commit_queries.by_id(id)
        return missing("commit", id) if commit.nil?

        record_links = linked(record_link_queries.for_record(KIND, commit.id))
        Success(serialized(Serializers::Commit, commit).merge(record_links:))
      end
    end
  end
end
