# frozen_string_literal: true

module API
  module Helpers
    class AnalyticsReader < Data.define(:range, :at, :path, :repos)
      RAW_REFUSAL = "hours, since, read_spread and navigation read raw visits, which the site keeps for " \
                    "#{Analytics::Repos::AnalyticsEventQueries::RETENTION_DAYS} days; start from or since inside " \
                    "them to get these. The daily counts still hold".freeze
      TOP = 25
      WEEKDAYS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze

      def call = path ? page_summary : summary

      private

      def change(found) = found.merge(from: found.fetch(:from).iso8601, to: found.fetch(:to).iso8601)

      def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

      def events = repo(:analytics_event_queries)

      def heading
        { from: range.first.iso8601, to: range.last.iso8601, time_zone: Blog::TimeZone::NAME }
      end

      def page_summary
        found = post
        summary = repo(:summarize_page).call(path:, from: range.first, to: range.last, top: TOP, post: found)
        days = summary.fetch(:days)

        {
          **heading,
          path:,
          **summary,
          days: dated(days),
          **raw,
          **(found ? { since_publish: since_publish(days, Blog::TimeZone.today(found.published_at)) } : {}),
        }
      end

      def post
        slug = path.delete_prefix("#{Blog::Constants::WRITING_PATH}/")
        repo(:post_queries).published_by_slug(slug) unless slug == path
      end

      def raw
        found = events.hourly_between(**raw_window)
        return { refused: RAW_REFUSAL } unless found

        timed(found).merge(events.navigation_between(**raw_window).transform_values { it.take(TOP) })
      end

      def raw_window
        from, to = Blog::TimeZone.day_bounds(range.first, range.last)

        { from: [from, at].compact.max, to:, path: }
      end

      def repo(name) = repos.fetch(name)

      def since_counts(found)
        { at: stamped(at), **found.fetch(:totals), **found.slice(:paths).transform_values { it.take(TOP) } }
      end

      def since_publish(days, first)
        days.select { it.fetch(:day) >= first }.map do |found|
          date = found.fetch(:day)
          { day: (date - first).to_i + 1, date: date.iso8601, **found.except(:day) }
        end
      end

      def site_wide(found)
        {
          change: change(found.fetch(:change)),
          feed: found.fetch(:feed).then { it.merge(days: dated(it.fetch(:days))) },
          weekday_hours: weekday_hours(found.fetch(:weekday_hours).fetch(:hours)),
        }
      end

      def stamped(time) = Blog::TimeZone.local(time).iso8601

      def summary
        found = repo(:summarize_analytics).call(from: range.first, to: range.last, top: TOP)

        {
          **heading,
          **found,
          days: dated(found.fetch(:days)),
          **raw,
          **site_wide(found),
        }
      end

      def timed(found)
        hours = found.fetch(:hours).map { it.merge(hour: stamped(it.fetch(:hour))) }
        read_spread = events.read_spread_between(**raw_window)

        at ? { hours:, read_spread:, since: since_counts(found) } : { hours:, read_spread: }
      end

      def weekday_hours(found, to = Blog::TimeZone.today)
        hours = found.each_with_index.map { |counts, hour| { hour:, **WEEKDAYS.zip(counts).to_h } }

        { from: events.retention_start(to).iso8601, to: to.iso8601, time_zone: Blog::TimeZone::NAME, hours: }
      end
    end
  end
end
