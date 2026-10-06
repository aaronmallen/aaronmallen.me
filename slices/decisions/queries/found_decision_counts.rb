# frozen_string_literal: true

module Decisions
  module Queries
    class FoundDecisionCounts
      include Deps[decision_repo: "repos.decision_repo"]

      def call(tag: nil, text: nil) = decision_repo.count_found(tag:, text:)
    end
  end
end
