# frozen_string_literal: true

module Projects
  module Queries
    class Live
      include Deps[project_repo: "repos.project_repo"]

      def call = project_repo.live
    end
  end
end
