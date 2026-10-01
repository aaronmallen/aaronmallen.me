# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsRollupRepo < Blog::DB::Repo
      ROWS = {
        analytics_rollup_paths: :paths,
        analytics_rollup_referrers: :referrers,
        analytics_rollup_countries: :countries,
        analytics_rollup_sources: :sources,
        analytics_rollup_devices: :devices,
        analytics_rollup_page_referrers: :page_referrers,
        analytics_rollup_page_countries: :page_countries,
      }.freeze
      TOP_ROWS = 100
      VIEW_DAYS = 90

      def by_day(day) = analytics_rollups.by_pk(day).one

      def countries(from:, to:) = analytics_rollup_countries.between(from, to).top_by_visitors.to_a

      def days(from:, to:) = analytics_rollups.between(from, to).oldest_first.to_a

      def devices(from:, to:, path: nil)
        analytics_rollup_devices.between(from, to).for_path(path).top_by_visitors.to_a
      end

      def newest_day = analytics_rollups.newest_day

      def page_countries(path:, from:, to:)
        analytics_rollup_page_countries.between(from, to).for_path(path).top_by_visitors.to_a
      end

      def page_days(path:, from:, to:) = analytics_rollup_paths.between(from, to).for_path(path).to_a

      def page_referrers(path:, from:, to:)
        analytics_rollup_page_referrers.between(from, to).for_path(path).top_by_visitors.to_a
      end

      def reach_in(month) = analytics_rollup_reach.in_month(month).to_a.to_h { [it.path, it.reach] }

      def referrers(from:, to:)
        analytics_rollup_referrers.between(from, to).top_by_visitors.limit(TOP_ROWS).to_a
      end

      def sources(from:, to:, path: nil)
        analytics_rollup_sources.between(from, to).for_path(path).top_by_visitors.to_a
      end

      def store(summary)
        transaction do
          analytics_rollups.command(:store).call(day: summary.day, **summary.totals.to_h)
          replace_rows(summary)
        end

        by_day(summary.day)
      end

      def store_reach(month, rows)
        transaction do
          analytics_rollup_reach.in_month(month).delete
          analytics_rollup_reach.stamped(:create, result: :many).call(rows.map { { month:, **it } })
        end
      end

      def top_paths(from:, to:) = analytics_rollup_paths.between(from, to).top_by_views.limit(TOP_ROWS).to_a

      def totals(from:, to:) = analytics_rollups.between(from, to).totals.one

      def views_by_path(from: Blog::TimeZone.today - (VIEW_DAYS - 1), to: Blog::TimeZone.today)
        analytics_rollup_paths.between(from, to).views_by_path.to_a.to_h { [it.path, it.views] }
      end

      def views_by_post(post_ids, from: Blog::TimeZone.today - (VIEW_DAYS - 1), to: Blog::TimeZone.today)
        views = analytics_rollup_paths.between(from, to).views_by_post(post_ids)

        views.to_a.to_h { [it.post_id, { views: it.views, visitors: it.visitors }] }
      end

      private

      def replace(relation, day, rows)
        relation.on(day).delete
        return if rows.empty?

        relation.stamped(:create, result: :many).call(rows.map { { day:, **it.to_h } })
      end

      def replace_rows(summary)
        ROWS.each { |relation, rows| replace(public_send(relation), summary.day, summary.public_send(rows)) }
      end
    end
  end
end
