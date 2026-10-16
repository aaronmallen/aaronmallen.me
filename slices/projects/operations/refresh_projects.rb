# frozen_string_literal: true

module Projects
  module Operations
    class RefreshProjects < Blog::Operation
      include Issues::Remote

      include Deps[
        client: "github.client",
        project_queries: "repos.project_queries",
        refresh_project: "operations.refresh_project",
      ]

      def call = step refresh

      private

      def refresh = remote(client) { Success(project_queries.tracked.count { refresh_project.refreshed?(it) }) }
    end
  end
end
