# frozen_string_literal: true

module Analytics
  module Queries
    class ScrollDepthsBetween
      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(path:, from:, to:)
        rolled = rollup_repo.scroll_depths(path:, from:, to:).map(&:to_h)
        live = unrolled_summaries.call(from:, to:).flat_map(&:scroll_depths).select { it.fetch(:path) == path }
        rows = rolled + live
        views = rows.sum { it.fetch(:views) }

        { views:, reached: Blog::Types::ScrollDepth.values.select(&:positive?).map { reached(it, rows, views) } }
      end

      private

      def reached(depth, rows, views)
        count = rows.select { it.fetch(:scroll_depth) >= depth }.sum { it.fetch(:views) }

        { depth:, views: count, share: views.zero? ? nil : (count.to_f / views).round(3) }
      end
    end
  end
end
