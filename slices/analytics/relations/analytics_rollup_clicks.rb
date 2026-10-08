# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupClicks < Blog::DB::Relation
      use :daily_rollup

      LINK = %i[link_host link_path].freeze

      schema :analytics_rollup_clicks, infer: true

      def top_by_clicks
        counts = unordered.select(*LINK) { integer.sum(clicks).as(:clicks) }.group(*LINK)

        counts.order { [sum(clicks).desc, link_host.asc, link_path.asc] }
      end
    end
  end
end
