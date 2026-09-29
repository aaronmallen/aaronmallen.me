# frozen_string_literal: true

module Tasks
  module Queries
    class SprintsBetween
      include Deps[sprint_repo: "repos.sprint_repo"]

      def call(from:, to:, page:) = sprint_repo.between(from, to, page)
    end
  end
end
