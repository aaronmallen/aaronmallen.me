# frozen_string_literal: true

module Projects
  module Operations
    class RefreshProject < Blog::Operation
      include Issues::Remote

      include Deps[
        client: "github.client",
        project_mutations: "repos.project_mutations",
        project_queries: "repos.project_queries",
      ]

      def call(id)
        project = project_queries.by_id(id)
        tracked = step found(project&.repo && project)

        step remote(client) { Success(refreshed?(tracked)) }
      end

      def refreshed?(project)
        stars = client.stars(project.repo)
        return false unless stars

        release = client.latest_release(project.repo)
        return false if project.stars == stars && project.release == release

        project_mutations.update(project.id, stars:, release:)
        true
      end
    end
  end
end
