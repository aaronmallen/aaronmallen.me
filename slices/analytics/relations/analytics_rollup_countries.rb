# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupCountries < Blog::DB::Relation
      schema :analytics_rollup_countries, infer: true

      def between(from, to) = where(day: from..to)

      def on(day) = where(day:)

      def top_by_views
        counts = unordered.select(:country_code) { integer.sum(views).as(:views) }.group(:country_code)

        counts.order { [sum(views).desc, country_code.asc] }
      end
    end
  end
end
