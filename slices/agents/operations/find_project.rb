# frozen_string_literal: true

module Agents
  module Operations
    class FindProject < Blog::Operation
      include Deps[project_queries: "projects.repos.project_queries"]

      def call(project: nil, repo: nil)
        return step(keyed(project)) if project

        project_queries.ids_by_repo(repo).first if repo
      end

      private

      def keyed(key)
        id = project_queries.id_by_key(key)
        id ? Success(id) : invalid(:project, Blog::Contract::MISSING)
      end
    end
  end
end
