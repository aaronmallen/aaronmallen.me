# frozen_string_literal: true

module Analytics
  module Queries
    class RollupForDay
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(day) = rollup_repo.by_day(day)
    end
  end
end
