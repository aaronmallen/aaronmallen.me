# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupScrollDepths < Blog::DB::Relation
      schema :analytics_rollup_scroll_depths, infer: true

      def between(from, to) = where(day: from..to)

      def by_depth = unordered.select(:scroll_depth) { integer.sum(views).as(:views) }.group(:scroll_depth)

      def for_path(path) = where(path:)

      def on(day) = where(day:)
    end
  end
end
