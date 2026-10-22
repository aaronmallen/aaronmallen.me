# frozen_string_literal: true

module Agents
  module Operations
    class ResolveProject < Blog::Operation
      PRIVATE = Blog::Types::ProjectVisibility["private"]

      include Deps[
        add_repo_rule: "tasks.operations.add_repo_rule",
        project_queries: "projects.repos.project_queries",
        save_project: "projects.operations.save_project",
      ]

      def call(project: nil, repo: nil)
        return step(keyed(project)) if project
        return unless repo

        project_queries.ids_by_repo(repo).first || step(created(repo))
      end

      private

      def created(repo)
        save_project.call({ name: repo.split("/").last, repo:, visibility: PRIVATE }).fmap { add_repo_rule.call(it).id }
      end

      def keyed(key)
        id = project_queries.id_by_key(key)
        id ? Success(id) : invalid(:project, Blog::Contract::MISSING)
      end
    end
  end
end
