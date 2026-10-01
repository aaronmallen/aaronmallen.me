# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupPageCountries < Blog::DB::Relation
      FIGURES = proc { [integer.sum(views).as(:views), integer.sum(visitors).as(:visitors)] }

      schema :analytics_rollup_page_countries, infer: true

      def between(from, to) = where(day: from..to)

      def for_path(path) = where(path:)

      def on(day) = where(day:)

      def top_by_visitors
        counts = unordered.select(:country_code, &FIGURES).group(:country_code)

        counts.order { [sum(visitors).desc, sum(views).desc, country_code.asc] }
      end
    end
  end
end
