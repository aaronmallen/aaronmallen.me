# frozen_string_literal: true

module API
  module Endpoints
    class ReadProject < Endpoint
      KIND = Blog::Types::RecordKind["project"]
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::Project::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[
        project_queries: "projects.repos.project_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def handle(id:)
        project = project_queries.by_id(id)
        return not_found(Wording.missing("project", id)) if project.nil?

        Success(serialized(Serializers::Project, project).merge(record_links: linked(KIND, project.id)))
      end
    end
  end
end
