# frozen_string_literal: true

module Projects
  module Queries
    class PublicGrid
      include Deps[project_repo: "repos.project_repo"]

      def call(limit = nil) = project_repo.public_grid(limit)
    end
  end
end
