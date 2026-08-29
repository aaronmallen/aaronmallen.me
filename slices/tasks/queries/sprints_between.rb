# frozen_string_literal: true

module Tasks
  module Queries
    class SprintsBetween
      include Deps[sprint_repo: "repos.sprint_repo"]

      def call(from:, to:) = sprint_repo.between(from, to)
    end
  end
end
