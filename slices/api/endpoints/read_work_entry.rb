# frozen_string_literal: true

module API
  module Endpoints
    class ReadWorkEntry < Endpoint
      KIND = Blog::Types::RecordKind["work_entry"]
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::WorkEntry::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[record_links: "links.queries.record_links", work_entry_queries: "projects.repos.work_entry_queries"]

      def handle(id:)
        entry = work_entry_queries.by_id(id)
        return not_found(Wording.missing("work entry", id)) if entry.nil?

        Success(serialized(Serializers::WorkEntry, entry).merge(record_links: linked(KIND, entry.id)))
      end
    end
  end
end
