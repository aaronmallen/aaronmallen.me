# frozen_string_literal: true

module MCP
  module Tools
    class AnalyticsReader < Data.define(:range, :at, :path, :context)
      PAGE_RANKED = %i[referrers countries].freeze
      RANKED = %i[paths referrers countries sources devices].freeze
      WEEKDAYS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze

      def call = path ? page_summary : summary

      private

      def between(repo, name, **) = dep(repo).public_send(name, from: range.first, to: range.last, **)

      def breakdowns(page_path)
        { sources: between(:analytics_page_queries, :sources_between, path: page_path).take(top),
          devices: between(:analytics_page_queries, :devices_between, path: page_path) }
      end

      def change(totals)
        to = range.first - 1
        from = to - (range.count - 1)
        before = dep(:analytics_rollup_queries).summary_between(from:, to:).fetch(:totals).fetch(:views)

        { from: from.iso8601, to: to.iso8601, views: before, percent: percent(totals.fetch(:views), before) }
      end

      def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

      def dep(name) = context.fetch(name)

      def events = dep(:analytics_event_queries)

      def feed = between(:feed_fetch_queries, :feed_subscribers_between).then { it.merge(days: dated(it.fetch(:days))) }

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

      def percent(views, before) = (Blog::Helpers::Figures.share(views - before, before) if before.positive?)

      def post
        slug = path.delete_prefix("#{Blog::Constants::WRITING_PATH}/")
        dep(:post_queries).published_by_slug(slug) unless slug == path
      end

      def published(days)
        found = post
        return {} unless found

        {
          since_publish: since_publish(days, Blog::TimeZone.today(found.published_at)),
          first_days: dep(:analytics_page_queries).first_days(path),
          unique_readers: dep(:post_reader_queries).unique_readers([found]).fetch(found.id),
        }
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

      def since_publish(days, first)
        days.select { it.fetch(:day) >= first }.map do |found|
          date = found.fetch(:day)
          { day: (date - first).to_i + 1, date: date.iso8601, **found.except(:day) }
        end
      end

      def site_wide(found)
        {
          weekday_hours:,
          change: change(found.fetch(:totals)),
          feed:,
          webmentions:,
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

      def webmention_post(found, counts) = { post_id: found.id, title: found.title, received: counts.fetch(found.id) }

      def webmentions
        counts = between(:webmention_queries, :received_by_post)
        posts = dep(:post_queries).by_ids(counts.keys).map { webmention_post(it, counts) }

        {
          pending: dep(:webmention_queries).pending_count,
          received: between(:webmention_queries, :received_between),
          posts: posts.sort_by { [-it[:received], it[:title]] }.take(top),
        }
      end

      def weekday_hours(to = Blog::TimeZone.today)
        found = events.weekday_hours(to:).fetch(:hours)
        hours = found.each_with_index.map { |counts, hour| { hour:, **WEEKDAYS.zip(counts).to_h } }

        { from: events.retention_start(to).iso8601, to: to.iso8601, time_zone: Blog::TimeZone::NAME, hours: }
      end
    end
  end
end
