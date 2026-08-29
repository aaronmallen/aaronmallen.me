# frozen_string_literal: true

module Analytics
  module Queries
    class CountryCounts
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:) = rollup_repo.countries(from:, to:)
    end
  end
end
