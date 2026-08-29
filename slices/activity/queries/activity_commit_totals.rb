# frozen_string_literal: true

module Activity
  module Queries
    class ActivityCommitTotals
      include Deps[activity_repo: "repos.activity_repo"]

      def call(from:, to:, **filters) = activity_repo.commit_totals(from:, to:, **filters)
    end
  end
end
