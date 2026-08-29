# frozen_string_literal: true

module Analytics
  module Queries
    class ReferrerCounts
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:) = rollup_repo.referrers(from:, to:)
    end
  end
end
