# frozen_string_literal: true

module API
  module Endpoints
    class ListProjects < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ projects: Helpers::Schema.list(Serializers::Project.reference) }).freeze

      include Deps[project_queries: "projects.repos.project_queries"]

      def handle
        Success(projects: serialized(Serializers::Project, project_queries.live + project_queries.archived))
      end
    end
  end
end
