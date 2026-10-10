# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsRollupMutations < Blog::DB::Repo
      ROWS = {
        analytics_rollup_referrers: :referrers,
        analytics_rollup_countries: :countries,
        analytics_rollup_sources: :sources,
        analytics_rollup_devices: :devices,
        analytics_rollup_page_referrers: :page_referrers,
        analytics_rollup_page_countries: :page_countries,
        analytics_rollup_scroll_depths: :scroll_depths,
        analytics_rollup_clicks: :clicks,
      }.freeze

      root :analytics_rollups

      def store(summary)
        transaction do
          analytics_rollups.command(:store).call(day: summary.day, **summary.totals.to_h)
          replace_rows(summary)
        end

        analytics_rollups.by_pk(summary.day).one
      end

      def store_reach(month, rows)
        transaction do
          analytics_rollup_reach.in_month(month).delete
          analytics_rollup_reach.stamped(:create, result: :many).call(rows.map { { month:, **it } })
        end
      end

      private

      def path_rows(summary)
        summary.paths.map { { **it.to_h, read_throughs: summary.read_throughs.fetch(it.path, 0) } }
      end

      def replace(relation, day, rows)
        relation.on(day).delete
        return if rows.empty?

        relation.stamped(:create, result: :many).call(rows.map { { day:, **it.to_h } })
      end

      def replace_rows(summary)
        replace(analytics_rollup_paths, summary.day, path_rows(summary))
        ROWS.each { |relation, rows| replace(public_send(relation), summary.day, summary.public_send(rows)) }
      end
    end
  end
end
