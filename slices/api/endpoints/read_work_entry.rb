# frozen_string_literal: true

module API
  module Endpoints
    class ReadWorkEntry < Endpoint
      KIND = Blog::Types::RecordKind["work_entry"]
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::WorkEntry::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        record_link_queries: "links.repos.record_link_queries", # rubocop:disable Hanami/UnusedDeps
        work_entry_queries: "projects.repos.work_entry_queries",
      ]

      def handle(id:)
        entry = work_entry_queries.by_id(id)
        return missing("work entry", id) if entry.nil?

        Success(serialized(Serializers::WorkEntry, entry).merge(record_links: links_for(entry.id)))
      end
    end
  end
end
