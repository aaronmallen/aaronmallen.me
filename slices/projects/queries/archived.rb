# frozen_string_literal: true

module Projects
  module Queries
    class Archived
      include Deps[project_repo: "repos.project_repo"]

      def call = project_repo.archived
    end
  end
end
