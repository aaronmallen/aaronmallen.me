# frozen_string_literal: true

module Projects
  module Queries
    class ById
      include Deps[project_repo: "repos.project_repo"]

      def call(id) = project_repo.by_id(id)
    end
  end
end
