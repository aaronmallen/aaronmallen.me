# frozen_string_literal: true

module Analytics
  module Queries
    class ViewTotals
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:) = rollup_repo.totals(from:, to:)
    end
  end
end
