# frozen_string_literal: true

module Decisions
  module Queries
    class ById
      include Deps[decision_repo: "repos.decision_repo"]

      def call(id) = decision_repo.by_id(id)
    end
  end
end
