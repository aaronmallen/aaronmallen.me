# frozen_string_literal: true

module API
  module Endpoints
    class ReadCommit < Endpoint
      KIND = Blog::Types::RecordKind["commit"]
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::Commit::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[commit_by_id: "record.queries.commit_by_id", record_links: "links.queries.record_links"]

      def handle(id:)
        commit = commit_by_id.call(id)
        return not_found(Wording.missing("commit", id)) if commit.nil?

        Success(serialized(Serializers::Commit, commit).merge(record_links: linked(KIND, commit.id)))
      end
    end
  end
end
