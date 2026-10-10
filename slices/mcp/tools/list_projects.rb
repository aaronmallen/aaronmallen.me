# frozen_string_literal: true

module MCP
  module Tools
    class ListProjects < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "List every project, public and private: the active ones first, then the archived ones, " \
                  "newest archived first. Each carries its status, its visibility, the day it started and the " \
                  "day it was archived as YYYY-MM-DD, its tags, repository, links, stars and latest release"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(server_context:)
          projects = dep(:project_queries, server_context).then { it.live + it.archived }

          answer(projects: projects.map { summary(it) })
        end

        def summary(project) = API::Serializers::Project.new(project).serializable_hash
      end
    end
  end
end
