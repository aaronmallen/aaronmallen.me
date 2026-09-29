# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsRollupRepo < Blog::DB::Repo
      VIEW_DAYS = 90

      def by_day(day) = analytics_rollups.by_pk(day).one

      def countries(from:, to:) = analytics_rollup_countries.between(from, to).top_by_visitors.to_a

      def days(from:, to:) = analytics_rollups.between(from, to).oldest_first.to_a

      def newest_day = analytics_rollups.newest_day

      def referrers(from:, to:) = analytics_rollup_referrers.between(from, to).top_by_visitors.to_a

      def store(summary)
        transaction do
          analytics_rollups.command(:store).call(day: summary.day, **summary.totals.to_h)
          replace_rows(summary)
        end

        by_day(summary.day)
      end

      def top_paths(from:, to:) = analytics_rollup_paths.between(from, to).top_by_views.to_a

      def totals(from:, to:) = analytics_rollups.between(from, to).totals.one

      def views_by_path(from: Blog::TimeZone.today - (VIEW_DAYS - 1), to: Blog::TimeZone.today)
        analytics_rollup_paths.between(from, to).views_by_path.to_a.to_h { [it.path, it.views] }
      end

      def views_by_post(post_ids, from: Blog::TimeZone.today - (VIEW_DAYS - 1), to: Blog::TimeZone.today)
        views = analytics_rollup_paths.between(from, to).views_by_post(post_ids)

        views.to_a.to_h { [it.post_id, it.views] }
      end

      private

      def replace(relation, day, rows)
        relation.on(day).delete
        return if rows.empty?

        relation.stamped(:create, result: :many).call(rows.map { { day:, **it.to_h } })
      end

      def replace_rows(summary)
        replace(analytics_rollup_paths, summary.day, summary.paths)
        replace(analytics_rollup_referrers, summary.day, summary.referrers)
        replace(analytics_rollup_countries, summary.day, summary.countries)
      end
    end
  end
end
