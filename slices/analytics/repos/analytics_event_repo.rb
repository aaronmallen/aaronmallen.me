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

      def internal_referrers_between(from:, to:, path:)
        window = analytics_events.between(from, to).for_path(path).known(:referrer_path)

        window.counts_by(:referrer_path, as: :path).to_a
      end

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

      def record_click(event_id:, limit:, link_host:, link_path:)
        analytics_clicks.claim(event_id:, limit:, link_host:, link_path:)
      end

      def record_read_seconds(visitor_hashes:, view_token:, read_seconds:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).record_read_seconds(read_seconds)
      end

      def record_scroll_depth(visitor_hashes:, view_token:, scroll_depth:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).record_scroll_depth(scroll_depth)
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
          devices: by_page(window.known(:device_class), :device_class),
          **page_only(window),
        )
      end

      def totals_between(from:, to:, path: nil) = scoped(analytics_events.between(from, to), path).totals.one

      def view_id(visitor_hashes:, view_token:, path:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).for_path(path).newest_id
      end

      def views_by_read_floor(from:, to:, floors:, path: nil)
        scoped(analytics_events.between(from, to), path).views_by_read_floor(floors)
      end

      def visit_ends_between(from:, to:, direction:) = analytics_events.between(from, to).visit_ends(direction)

      def visitors_on(day) = analytics_events.on_day(day).visitor_count

      private

      def by_page(window, column)
        site = window.counts_by(column).to_a.map { { path: nil, **it.to_h } }

        site + window.page_counts_by(column).to_a.map(&:to_h)
      end

      def clicks(window) = { clicks: window.clicks.to_a.map(&:to_h) }

      def page_only(window)
        {
          page_referrers: window.page_counts_by(:referrer_host, as: :host).to_a.map(&:to_h),
          page_countries: window.page_counts_by(:country_code).to_a.map(&:to_h),
          scroll_depths: window.known(:scroll_depth).page_counts_by(:scroll_depth).to_a.map(&:to_h),
          read_throughs: window.read_throughs_by_path.to_a.to_h { [it.path, it.read_throughs] },
          **clicks(window),
        }
      end

      def scoped(window, path) = path ? window.for_path(path) : window
    end
  end
end
