# frozen_string_literal: true

module API
  module Endpoints
    class ReadProject < Endpoint
      KIND = Blog::Types::RecordKind["project"]
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::Project::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        project_queries: "projects.repos.project_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def handle(id:)
        project = project_queries.by_id(id)
        return missing("project", id) if project.nil?

        record_links = linked(record_link_queries.for_record(KIND, project.id))
        Success(serialized(Serializers::Project, project).merge(record_links:))
      end
    end
  end
end
