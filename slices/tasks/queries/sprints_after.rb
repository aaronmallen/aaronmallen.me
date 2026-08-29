# frozen_string_literal: true

module Tasks
  module Queries
    class SprintsAfter
      include Deps[sprint_repo: "repos.sprint_repo"]

      def call(date) = sprint_repo.after(date)
    end
  end
end
