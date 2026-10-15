# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsEventQueries < Blog::DB::Repo
      FLOORS = [0, 1, 10, 30, 60, 120, 300, 600].freeze
      MEMO = :analytics_event_memo
      RETENTION_DAYS = 90

      include Deps["settings"]

      def complete_from
        [oldest_day, retention_start].compact.min
      end

      def count_from_address_since(address_hashes, time)
        analytics_events.from_address(address_hashes).since(time).count
      end

      def hourly_between(from:, to:, path: nil)
        return unless kept?(from)

        window = scoped(analytics_events.between(from, to), path)
        found = { hours: window.hourly.to_a.map(&:to_h), totals: window.totals.one.to_h }
        path ? found : found.merge(paths: ranked_paths(from, to))
      end

      def live_reach(from:, to:, path: nil) = scoped(analytics_events.between_days(from, to), path).reach

      def memoizing
        was = Fiber[MEMO]
        Fiber[MEMO] = was || {}
        yield
      ensure
        Fiber[MEMO] = was
      end

      def navigation_between(from:, to:, path: nil)
        return unless kept?(from)

        path ? { internal_referrers: internal_referrers(from, to, path) } : visit_ends(from, to)
      end

      def oldest_day
        memo(:oldest_day) { analytics_events.oldest_occurred_at&.then { Blog::TimeZone.today(it) } }
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

      def retention_start(to = Blog::TimeZone.today) = to - (RETENTION_DAYS - 1)

      def summary_for(day) = memo([:summary, day]) { summarize(day) }

      def view_id(visitor_hashes:, view_token:, path:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).for_path(path).newest_id
      end

      def views_on(days, paths: nil)
        return Blog::Constants::EMPTY_ARRAY if days.empty?

        window = scoped(analytics_events.between_days(days.min, days.max), paths)
        window.views_by_day_and_path(**read_through).to_a.select { days.include?(it.fetch(:day)) }
      end

      def visitors_on(day) = analytics_events.on_day(day).visitor_count

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

      def memo(key)
        found = Fiber[MEMO]
        found ? found.fetch(key) { found[key] = yield } : yield
      end

      def page_only(window)
        {
          page_referrers: window.page_counts_by(:referrer_host, as: :host).to_a.map(&:to_h),
          page_countries: window.page_countries.to_a.map(&:to_h),
          scroll_depths: window.known(:scroll_depth).page_counts_by(:scroll_depth).to_a.map(&:to_h),
          read_throughs: read_throughs(window).to_a.to_h { [it.path, it.read_throughs] },
          **clicks(window),
        }
      end

      def ranked_paths(from, to)
        rows = analytics_events.between(from, to).counts_by(:path).to_a.map(&:to_h)

        rows.sort_by { [-it.fetch(:views), it.fetch(:path)] }
      end

      def read_through
        depth, seconds = settings.analytics.values_at(:read_through_scroll_depth, :read_through_seconds)

        { scroll_depth: depth, read_seconds: seconds }
      end

      def read_throughs(window) = window.read_throughs_by_path(**read_through)

      def scoped(window, path) = path ? window.for_path(path) : window

      def site_only(window)
        {
          referrers: window.counts_by(:referrer_host, as: :host).to_a,
          countries: window.countries.to_a,
          hours: window.visitors_by_hour,
        }
      end

      def summarize(day)
        window = analytics_events.on_day(day)

        Structs::AnalyticsSummary.new(
          day:,
          totals: window.totals.one,
          paths: window.paths.to_a,
          **site_only(window),
          sources: by_page(window.known(:source), :source),
          devices: by_page(window.known(:device_class), :device_class),
          **page_only(window),
        )
      end

      def visit_ends(from, to)
        window = analytics_events.between(from, to)

        { entry_pages: window.visit_ends(:asc), exit_pages: window.visit_ends(:desc) }
      end
    end
  end
end
