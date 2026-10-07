# frozen_string_literal: true

module API
  module Endpoints
    class ReadCommit < Endpoint
      KIND = Blog::Types::RecordKind["commit"]
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::Commit::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        commit_queries: "record.repos.commit_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def handle(id:)
        commit = commit_queries.by_id(id)
        return not_found(Wording.missing("commit", id)) if commit.nil?

        Success(serialized(Serializers::Commit, commit).merge(record_links: linked(KIND, commit.id)))
      end
    end
  end
end
