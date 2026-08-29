# frozen_string_literal: true

module Analytics
  module Queries
    class RollupsBetween
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:) = rollup_repo.days(from:, to:)
    end
  end
end
