# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupClicks < Blog::DB::Relation
      LINK = %i[link_host link_path].freeze

      schema :analytics_rollup_clicks, infer: true

      def between(from, to) = where(day: from..to)

      def for_path(path) = where(path:)

      def on(day) = where(day:)

      def top_by_clicks
        counts = unordered.select(*LINK) { integer.sum(clicks).as(:clicks) }.group(*LINK)

        counts.order { [sum(clicks).desc, link_host.asc, link_path.asc] }
      end
    end
  end
end
