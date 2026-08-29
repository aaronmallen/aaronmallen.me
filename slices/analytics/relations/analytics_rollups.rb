# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollups < Blog::DB::Relation
      TOTALS = proc do
        [
          integer.coalesce(integer.sum(views), 0).as(:views),
          integer.coalesce(integer.sum(visitors), 0).as(:visitors),
          integer.coalesce(integer.sum(read_seconds), 0).as(:read_seconds),
        ]
      end

      schema :analytics_rollups, infer: true

      def between(from, to) = where(day: from..to)

      def newest_day = unordered.dataset.max(:day)

      def oldest_first = order(self[:day].asc)

      def totals = unordered.select(&TOTALS)
    end
  end
end
