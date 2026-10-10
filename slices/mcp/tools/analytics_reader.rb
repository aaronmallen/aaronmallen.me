# frozen_string_literal: true

module MCP
  module Tools
    class AnalyticsReader < Data.define(:range, :at, :path, :context)
      PAGE_RANKED = %i[referrers countries].freeze
      RANKED = %i[paths referrers countries sources devices].freeze

      def call = path ? page_summary : summary

      private

      def between(repo, name, **) = dep(repo).public_send(name, from: range.first, to: range.last, **)

      def breakdowns(page_path)
        { sources: between(:analytics_page_queries, :sources_between, path: page_path).take(top),
          devices: between(:analytics_page_queries, :devices_between, path: page_path) }
      end

      def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

      def dep(name) = context.fetch(name)

      def deps(keys) = keys.to_h { [it, dep(it)] }

      def events = dep(:analytics_event_queries)

      def heading
        { from: range.first.iso8601, to: range.last.iso8601, time_zone: Blog::TimeZone::NAME }
      end

      def page
        found = between(:analytics_page_queries, :page_between, path:)
        read_throughs = read_throughs_by_path.fetch(path, 0)

        found.merge(totals: found.fetch(:totals).merge(read_throughs:, bounces: found.fetch(:bounces)))
      end

      def page_ranked(found)
        {
          **PAGE_RANKED.to_h { [it, found.fetch(it).take(top)] },
          **breakdowns(path),
          clicks: between(:analytics_page_queries, :clicks_between, path:).take(top),
          scroll: between(:analytics_page_queries, :scroll_depths_between, path:),
        }
      end

      def page_summary
        found = page
        days = found.fetch(:days)

        {
          **heading,
          path:,
          totals: totals(found, path:),
          days: dated(days),
          **page_ranked(found),
          **raw,
          **published(days),
        }
      end

      def post
        slug = path.delete_prefix("#{Blog::Constants::WRITING_PATH}/")
        dep(:post_queries).published_by_slug(slug) unless slug == path
      end

      def published(days)
        found = post
        return {} unless found

        PublishedPost.call(found, path, days, **deps(PublishedPost::QUERIES))
      end

      def ranked
        found = between(:analytics_rollup_queries, :summary_between)
        read_throughs = read_throughs_by_path

        found.merge(
          breakdowns(nil),
          paths: found.fetch(:paths).map { ranked_path(it, read_throughs) },
          totals: found.fetch(:totals).merge(read_throughs: read_throughs.values.sum),
        )
      end

      def ranked_path(found, read_throughs)
        found.merge(title: Untrusted.call(found[:title]), read_throughs: read_throughs.fetch(found.fetch(:path), 0))
      end

      def raw
        found = events.hourly_between(**raw_window)
        return { refused: ReadAnalytics::RAW_REFUSAL } unless found

        timed(found).merge(events.navigation_between(**raw_window).transform_values { it.take(top) })
      end

      def raw_window
        from, to = Blog::TimeZone.day_bounds(range.first, range.last)

        { from: [from, at].compact.max, to:, path: }
      end

      def read_throughs_by_path = between(:analytics_rollup_queries, :read_throughs_between)

      def since_counts(found)
        { at: stamped(at), **found.fetch(:totals), **found.slice(:paths).transform_values { it.take(top) } }
      end

      def site_wide(found)
        {
          weekday_hours: WeekdayGrid.call(events),
          change: PriorRange.call(found.fetch(:totals), range, dep(:analytics_rollup_queries)),
          **Following.call(range, top:, **deps(Following::QUERIES)),
        }
      end

      def stamped(time) = Blog::TimeZone.local(time).iso8601

      def summary
        found = ranked

        {
          **heading,
          totals: totals(found),
          days: dated(found.fetch(:days)),
          **raw,
          **RANKED.to_h { [it, found.fetch(it).take(top)] },
          **site_wide(found),
        }
      end

      def timed(found)
        hours = found.fetch(:hours).map { it.merge(hour: stamped(it.fetch(:hour))) }
        read_spread = events.read_spread_between(**raw_window)

        at ? { hours:, read_spread:, since: since_counts(found) } : { hours:, read_spread: }
      end

      def top = ReadAnalytics::TOP

      def totals(found, path: nil)
        found.fetch(:totals).merge(reach: between(:analytics_rollup_queries, :reach_between, path:))
      end
    end
  end
end
