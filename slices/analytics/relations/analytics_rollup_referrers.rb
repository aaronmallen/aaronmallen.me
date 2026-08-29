# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupReferrers < Blog::DB::Relation
      schema :analytics_rollup_referrers, infer: true

      def between(from, to) = where(day: from..to)

      def on(day) = where(day:)

      def top_by_views
        counts = unordered.select(:host) { integer.sum(views).as(:views) }.group(:host)

        counts.order { [sum(views).desc, host.asc] }
      end
    end
  end
end
