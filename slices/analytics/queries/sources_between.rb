# frozen_string_literal: true

module Analytics
  module Queries
    class SourcesBetween
      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(from:, to:, path: nil)
        rolled = rollup_repo.sources(from:, to:, path:).map(&:to_h)
        live = unrolled_summaries.call(from:, to:).flat_map(&:sources).select { it.fetch(:path) == path }

        RankedRows.call(rolled + live, key: :source)
      end
    end
  end
end
