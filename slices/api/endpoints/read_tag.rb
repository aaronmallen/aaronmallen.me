# frozen_string_literal: true

module API
  module Endpoints
    class ReadTag < Endpoint
      GATED = { OperationTable::MAIL => :messages, OperationTable::NOTES => :notes }.freeze
      SCOPED = true
      SCHEMA = {
        additionalProperties: false,
        properties: {
          name: { type: "string", description: "the tag's name, in either scope or in the project" },
          project: {
            type: "string",
            description: "the key of the project whose own tag to read, as POD; none for a public or private tag",
          },
          kind: {
            type: "string",
            enum: Blog::Types::TagKind.values,
            description: [
              "one kind to page through; every kind when you leave it out.",
              "Only a project's own tag has notes and messages, and each needs its scope",
            ].join(" "),
          },
          page: Helpers::Paging::PAGE,
        },
        required: %w[name],
      }.freeze

      REPLY = Serializers::TagOverview::SCHEMA

      include Deps[project_queries: "projects.repos.project_queries", tag_queries: "tags.repos.tag_queries"]

      def handle(name:, scopes:, kind: nil, page: 1, project: nil)
        project_id = project_queries.id_by_key(project.strip) if project
        return missing("project", project, by: "key") if project && !project_id

        hidden = GATED.except(*scopes).values
        overview = tag_queries.overview(name.strip.downcase, page_of(page), kind:, project_id:, hidden:)
        return missing("tag", name, by: "name") if overview.nil?

        Success(serialized(Serializers::TagOverview, overview))
      end
    end
  end
end
