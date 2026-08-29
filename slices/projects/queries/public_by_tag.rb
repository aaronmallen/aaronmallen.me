# frozen_string_literal: true

module Projects
  module Queries
    class PublicByTag
      include Deps[project_repo: "repos.project_repo"]

      def call(tag) = project_repo.public_by_tag(tag)
    end
  end
end
