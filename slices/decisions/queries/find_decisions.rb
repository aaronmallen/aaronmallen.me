# frozen_string_literal: true

module Decisions
  module Queries
    class FindDecisions
      include Deps[decision_repo: "repos.decision_repo"]

      def call(page:, status: nil, tag: nil) = decision_repo.listed(page, status:, tag:)
    end
  end
end
