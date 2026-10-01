# frozen_string_literal: true

module Analytics
  module Queries
    class PageBetween
      FIGURES = %i[views visitors read_seconds].freeze
      ZERO_DAY = FIGURES.to_h { [it, 0] }.freeze

      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(path:, from:, to:)
        found = rollup_repo.page_days(path:, from:, to:).to_h { [it.day, figures(it)] }
        unrolled_summaries.call(from:, to:).each { found[it.day] = live(it, path) }
        days = (from..to).map { { day: it, **found.fetch(it, ZERO_DAY) } }

        { days:, totals: FIGURES.to_h { |key| [key, days.sum { it.fetch(key) }] } }
      end

      private

      def figures(row) = row.to_h.slice(*FIGURES)

      def live(summary, path)
        row = summary.paths.find { it.path == path }
        row ? figures(row) : ZERO_DAY
      end
    end
  end
end
