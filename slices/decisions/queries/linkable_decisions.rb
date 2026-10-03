# frozen_string_literal: true

module Decisions
  module Queries
    class LinkableDecisions
      include Deps[decision_repo: "repos.decision_repo"]

      def matching(text, limit:) = decision_repo.linkable(:decisions, text:, limit:)

      def named(ids) = decision_repo.linkable(:decisions, ids:)
    end
  end
end
