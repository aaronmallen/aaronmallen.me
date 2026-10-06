# frozen_string_literal: true

module Projects
  module Queries
    class ByTag
      include Deps[project_repo: "repos.project_repo"]

      def call(tag) = project_repo.by_tag(tag)
    end
  end
end
