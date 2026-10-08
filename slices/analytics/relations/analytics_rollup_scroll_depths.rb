# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupScrollDepths < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_scroll_depths, infer: true

      def by_depth = unordered.select(:scroll_depth) { integer.sum(views).as(:views) }.group(:scroll_depth)
    end
  end
end
