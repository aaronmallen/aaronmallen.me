# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsEventRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def claim(address_hash:, limit:, since:, **attrs)
        analytics_events.claim(address_hash:, limit:, since:, **attrs)
      end

      def complete_from(kept_days) = [oldest_day, Blog::TimeZone.today - (kept_days - 1)].compact.min

      def count_from_address_since(address_hash, time) = analytics_events.from_address(address_hash).since(time).count

      def delete_before(time) = analytics_events.occurred_before(time).delete

      def hours_between(from:, to:, path: nil) = scoped(analytics_events.between(from, to), path).hourly.to_a

      def median_read_seconds(from:, to:, path: nil) = scoped(analytics_events.between(from, to), path).read_median

      def oldest_day
        occurred_at = analytics_events.oldest_occurred_at
        Blog::TimeZone.today(occurred_at) if occurred_at
      end

      def paths_between(from:, to:) = analytics_events.between(from, to).counts_by(:path).to_a

      def reach_between(from:, to:, path: nil) = scoped(analytics_events.between_days(from, to), path).reach

      def reach_by_path(from:, to:)
        window = analytics_events.between_days(from, to)

        [{ path: nil, reach: window.reach }, *window.reach_by_path.to_a.map(&:to_h)]
      end

      def record_read_seconds(visitor_hash:, view_token:, read_seconds:)
        analytics_events.for_visitor(visitor_hash).for_view(view_token).record_read_seconds(read_seconds)
      end

      def summary_for(day)
        window = analytics_events.on_day(day)

        Structs::AnalyticsSummary.new(
          day:,
          totals: window.totals.one,
          paths: window.paths.to_a,
          referrers: window.counts_by(:referrer_host, as: :host).to_a,
          countries: window.counts_by(:country_code).to_a,
          sources: by_page(window.known(:source), :source),
        )
      end

      def totals_between(from:, to:, path: nil) = scoped(analytics_events.between(from, to), path).totals.one

      def views_by_read_floor(from:, to:, floors:, path: nil)
        scoped(analytics_events.between(from, to), path).views_by_read_floor(floors)
      end

      def visitors_on(day) = analytics_events.on_day(day).visitor_count

      private

      def by_page(window, column)
        site = window.counts_by(column).to_a.map { { path: nil, **it.to_h } }

        site + window.page_counts_by(column).to_a.map(&:to_h)
      end

      def scoped(window, path) = path ? window.for_path(path) : window
    end
  end
end
