# frozen_string_literal: true

module Decisions
  module Queries
    class CountByStatus
      include Deps[decision_repo: "repos.decision_repo"]

      def call = decision_repo.count_by_status
    end
  end
end
