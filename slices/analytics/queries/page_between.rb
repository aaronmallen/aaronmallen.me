# frozen_string_literal: true

module Analytics
  module Queries
    class PageBetween
      FIGURES = %i[views visitors read_seconds].freeze
      COUNTED = [*FIGURES, :bounces].freeze
      RANKED = { countries: :country_code, referrers: :host }.freeze
      ZERO_DAY = COUNTED.to_h { [it, 0] }.freeze

      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(path:, from:, to:)
        window = { path:, from:, to: }
        live = unrolled_summaries.call(from:, to:)
        days = days(window, live)

        {
          bounces: days.sum { it.fetch(:bounces) },
          days: days.map { it.except(:bounces) },
          totals: FIGURES.to_h { |key| [key, days.sum { it.fetch(key) }] },
          **RANKED.to_h { |name, key| [name, ranked(name, key, window, live)] },
        }
      end

      private

      def days(window, live)
        found = rollup_repo.page_days(**window).to_h { [it.day, figures(it)] }
        live.each { found[it.day] = live_day(it, window.fetch(:path)) }

        (window.fetch(:from)..window.fetch(:to)).map { { day: it, **found.fetch(it, ZERO_DAY) } }
      end

      def figures(row) = row.to_h.slice(*COUNTED)

      def live_day(summary, path)
        row = summary.paths.find { it.path == path }
        row ? figures(row) : ZERO_DAY
      end

      def live_rows(name, path, live) = live.flat_map { it.public_send(name) }.select { it.fetch(:path) == path }

      def ranked(name, key, window, live)
        rolled = rollup_repo.public_send(:"page_#{name}", **window).map(&:to_h)
        rows = rolled + live_rows(:"page_#{name}", window.fetch(:path), live)

        RankedRows.call(rows, key:)
      end
    end
  end
end
