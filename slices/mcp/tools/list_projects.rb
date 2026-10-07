# frozen_string_literal: true

module MCP
  module Tools
    class ListProjects < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "List every project, public and private: the active ones first, then the archived ones, " \
                  "newest archived first. Each carries its status, its visibility, the day it started and the " \
                  "day it was archived as YYYY-MM-DD, its tags, repository, links, stars and latest release"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          projects = dep(:project_queries, server_context).then { it.live + it.archived }

          answer(projects: projects.map { summary(it) })
        end

        def summary(project)
          {
            id: project.id,
            name: project.name,
            tagline: project.tagline,
            status: project.status,
            visibility: project.visibility,
            started_on: project.started_on&.iso8601,
            archived_on: project.archived_on&.iso8601,
            tags: project.tags.map(&:name),
            repo: project.repo,
            url: project.url,
            og_image_url: project.og_image_url,
            stars: project.stars,
            release: project.release,
          }
        end
      end
    end
  end
end
