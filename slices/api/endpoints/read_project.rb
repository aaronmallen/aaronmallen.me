# frozen_string_literal: true

module API
  module Endpoints
    class ReadProject < Endpoint
      KIND = Blog::Types::RecordKind["project"]
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::Project::SCHEMA, record_links: Serializers::Link::GROUPS).freeze

      include Deps[project_by_id: "projects.queries.by_id", record_links: "links.queries.record_links"]

      def handle(id:)
        project = project_by_id.call(id)
        return not_found(Wording.missing("project", id)) if project.nil?

        Success(serialized(Serializers::Project, project).merge(record_links: linked(KIND, project.id)))
      end
    end
  end
end
