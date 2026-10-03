# frozen_string_literal: true

module Projects
  module Queries
    class LinkableProjects
      include Deps[project_repo: "repos.project_repo"]

      def matching(text, limit:) = project_repo.linkable(:projects, text:, limit:)

      def named(ids) = project_repo.linkable(:projects, ids:)
    end
  end
end
