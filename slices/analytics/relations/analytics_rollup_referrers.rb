# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupReferrers < Blog::DB::Relation
      FIGURES = proc { [integer.sum(views).as(:views), integer.sum(visitors).as(:visitors)] }

      schema :analytics_rollup_referrers, infer: true

      def between(from, to) = where(day: from..to)

      def on(day) = where(day:)

      def top_by_visitors
        counts = unordered.select(:host, &FIGURES).group(:host)

        counts.order { [sum(visitors).desc(nulls: :last), sum(views).desc, host.asc] }
      end
    end
  end
end
