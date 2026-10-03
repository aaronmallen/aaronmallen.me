# frozen_string_literal: true

module Decisions
  module Queries
    class ByStatus
      include Deps[decision_repo: "repos.decision_repo"]

      def call(status, page) = decision_repo.page_by_status(status, page)
    end
  end
end
