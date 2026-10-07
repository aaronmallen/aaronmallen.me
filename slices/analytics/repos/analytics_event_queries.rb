# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsEventQueries < DB::Repo
      FLOORS = [0, 1, 10, 30, 60, 120, 300, 600].freeze
      HOURS = (0..23)
      WEEKDAYS = (1..7)

      def complete_from
        [oldest_day, Blog::TimeZone.today - (Operations::PruneAnalyticsEvents::RETENTION_DAYS - 1)].compact.min
      end

      def count_from_address_since(address_hash, time) = analytics_events.from_address(address_hash).since(time).count

      def hourly_between(from:, to:, path: nil)
        return unless kept?(from)

        window = scoped(analytics_events.between(from, to), path)
        found = { hours: window.hourly.to_a.map(&:to_h), totals: window.totals.one.to_h }
        path ? found : found.merge(paths: ranked_paths(from, to))
      end

      def live_reach(from:, to:, path: nil) = scoped(analytics_events.between_days(from, to), path).reach

      def navigation_between(from:, to:, path: nil)
        return unless kept?(from)

        path ? { internal_referrers: internal_referrers(from, to, path) } : visit_ends(from, to)
      end

      def oldest_day
        occurred_at = analytics_events.oldest_occurred_at
        Blog::TimeZone.today(occurred_at) if occurred_at
      end

      def reach_by_path(from:, to:)
        window = analytics_events.between_days(from, to)

        [{ path: nil, reach: window.reach }, *window.reach_by_path.to_a.map(&:to_h)]
      end

      def read_spread_between(from:, to:, path: nil)
        return unless kept?(from)

        window = scoped(analytics_events.between(from, to), path)

        { median: window.read_median&.round(1), buckets: buckets(window.views_by_read_floor(FLOORS)) }
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

      def view_id(visitor_hashes:, view_token:, path:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).for_path(path).newest_id
      end

      def visitors_on(day) = analytics_events.on_day(day).visitor_count

      def weekday_hours(to: Blog::TimeZone.today)
        days = Operations::PruneAnalyticsEvents::RETENTION_DAYS
        counts = analytics_events.between_days(to - (days - 1), to).visitors_by_weekday_hour

        { days:, hours: HOURS.map { |hour| WEEKDAYS.map { |weekday| counts.fetch([weekday, hour], 0) } } }
      end

      private

      def buckets(views)
        ceilings = FLOORS.drop(1).map(&:pred) << Operations::RecordVisit::MAX_READ_SECONDS

        FLOORS.zip(ceilings).map { |floor, ceiling| { from: floor, to: ceiling, views: views.fetch(floor, 0) } }
      end

      def by_page(window, column)
        site = window.counts_by(column).to_a.map { { path: nil, **it.to_h } }

        site + window.page_counts_by(column).to_a.map(&:to_h)
      end

      def clicks(window) = { clicks: window.clicks.to_a.map(&:to_h) }

      def internal_referrers(from, to, path)
        window = analytics_events.between(from, to).for_path(path).known(:referrer_path)
        rows = window.counts_by(:referrer_path, as: :path).to_a.map(&:to_h)

        rows.sort_by { [-it.fetch(:visitors), -it.fetch(:views), it.fetch(:path)] }
      end

      def kept?(from) = from >= Blog::TimeZone.day_start(complete_from)

      def page_only(window)
        {
          page_referrers: window.page_counts_by(:referrer_host, as: :host).to_a.map(&:to_h),
          page_countries: window.page_counts_by(:country_code).to_a.map(&:to_h),
          scroll_depths: window.known(:scroll_depth).page_counts_by(:scroll_depth).to_a.map(&:to_h),
          read_throughs: window.read_throughs_by_path.to_a.to_h { [it.path, it.read_throughs] },
          **clicks(window),
        }
      end

      def ranked_paths(from, to)
        rows = analytics_events.between(from, to).counts_by(:path).to_a.map(&:to_h)

        rows.sort_by { [-it.fetch(:views), it.fetch(:path)] }
      end

      def scoped(window, path) = path ? window.for_path(path) : window

      def visit_ends(from, to)
        window = analytics_events.between(from, to)

        { entry_pages: window.visit_ends(:asc), exit_pages: window.visit_ends(:desc) }
      end
    end
  end
end
