# frozen_string_literal: true

module Decisions
  module Queries
    class ByTag
      include Deps[decision_repo: "repos.decision_repo"]

      def call(tag) = decision_repo.by_tag(tag)
    end
  end
end
