# frozen_string_literal: true

module Agents
  module Operations
    class ResolveProject < Blog::Operation
      PRIVATE = Blog::Types::ProjectVisibility["private"]

      include Deps[
        add_repo_rule: "tasks.operations.add_repo_rule",
        find_project: "operations.find_project",
        save_project: "projects.operations.save_project",
      ]

      def call(project: nil, repo: nil)
        id = step find_project.call(project:, repo:)
        return id if id || repo.nil?

        step created(repo)
      end

      private

      def created(repo)
        save_project.call({ name: repo.split("/").last, repo:, visibility: PRIVATE }).fmap { add_repo_rule.call(it).id }
      end
    end
  end
end
