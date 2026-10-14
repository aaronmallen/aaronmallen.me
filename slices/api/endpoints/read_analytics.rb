# frozen_string_literal: true

module API
  module Endpoints
    class ReadAnalytics < Endpoint
      SINCE_REFUSAL = "give since as an ISO 8601 time, such as 2026-10-01T09:00:00-05:00"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::RANGE,
          path: { type: "string",
                  description: "one page to read alone, such as #{Blog::Constants::WRITING_PATH}/hello" },
          since: { type: "string", description: "an ISO 8601 time, such as 2026-10-01T09:00:00-05:00" },
        },
        required: %w[from to],
      }.freeze

      INTEGER = Helpers::Schema::INTEGER
      COUNTS = { views: INTEGER, visitors: INTEGER }.freeze
      MAYBE_INTEGER = Helpers::Schema.nullable(INTEGER)
      MAYBE_STRING = Helpers::Schema.nullable(Helpers::Schema::STRING)
      STRING = Helpers::Schema::STRING

      def self.rows(properties, optional: {}) = Helpers::Schema.list(Helpers::Schema.object(properties, optional:))

      DAYS = rows({ day: Helpers::Schema::DAY, **COUNTS }, optional: { read_seconds: INTEGER })
      HOURS = rows({ hour: Helpers::Schema::STAMP, **COUNTS })
      PAGES = rows({ path: STRING, visitors: INTEGER })

      MEDIAN = { type: "number", description: "the middle read_seconds of the views that read" }.freeze
      READ_SPREAD = Helpers::Schema.object(
        {
          buckets: rows({ from: INTEGER, to: INTEGER, views: INTEGER }),
          median: Helpers::Schema.nullable(MEDIAN),
        },
      ).freeze

      SINCE = Helpers::Schema.object(
        { at: Helpers::Schema::STAMP, views: INTEGER, visitors: INTEGER, read_seconds: INTEGER },
        optional: { paths: rows({ path: STRING, **COUNTS }) },
      ).freeze

      TOTALS = Helpers::Schema.object(
        { views: INTEGER, visitors: INTEGER, read_seconds: INTEGER, read_throughs: INTEGER, reach: MAYBE_INTEGER },
        optional: { bounces: INTEGER },
      ).freeze

      SCROLL = Helpers::Schema.object(
        {
          views: INTEGER,
          reached: rows({ depth: INTEGER, views: INTEGER, share: Helpers::Schema.nullable({ type: "number" }) }),
        },
      ).freeze

      WEEKDAY_HOURS = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          time_zone: STRING,
          hours: rows({ hour: INTEGER, **Helpers::AnalyticsReader::WEEKDAYS.to_h { [it, INTEGER] } }),
        },
      ).freeze

      CHANGE = Helpers::Schema.object(
        { from: Helpers::Schema::DAY, to: Helpers::Schema::DAY, views: INTEGER, percent: MAYBE_INTEGER },
      ).freeze

      FEED = Helpers::Schema.object(
        {
          days: rows({ day: Helpers::Schema::DAY, subscribers: INTEGER }),
          latest: INTEGER,
          aggregators: rows({ aggregator: STRING, subscribers: INTEGER }),
        },
      ).freeze

      WEBMENTIONS = Helpers::Schema.object(
        {
          pending: INTEGER,
          received: INTEGER,
          posts: rows({ post_id: INTEGER, title: STRING, received: INTEGER }),
        },
      ).freeze

      FIRST_DAYS = Helpers::Schema.object(
        { days: Helpers::Schema.list(INTEGER), median: Helpers::Schema.list(INTEGER), span: INTEGER },
      ).freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          time_zone: STRING,
          totals: TOTALS,
          days: DAYS,
          referrers: rows({ host: MAYBE_STRING, views: INTEGER, visitors: MAYBE_INTEGER }),
          countries: rows({ country_code: STRING, country_name: MAYBE_STRING, views: INTEGER,
                            visitors: MAYBE_INTEGER }),
          sources: rows({ source: STRING, **COUNTS }),
          devices: rows({ device_class: { type: "string", enum: Blog::Types::DeviceClass.values }, **COUNTS }),
        },
        optional: {
          path: STRING,
          paths: rows(
            { path: STRING, title: MAYBE_STRING, views: INTEGER, visitors: INTEGER, read_seconds: INTEGER,
              bounces: INTEGER, read_throughs: INTEGER },
          ),
          clicks: rows({ link_host: STRING, link_path: STRING, clicks: INTEGER }),
          scroll: SCROLL,
          hours: HOURS,
          read_spread: READ_SPREAD,
          since: SINCE,
          entry_pages: PAGES,
          exit_pages: PAGES,
          internal_referrers: rows({ path: STRING, **COUNTS }),
          refused: { type: "string", description: "why the answer leaves out what it reads from raw visits" },
          weekday_hours: WEEKDAY_HOURS,
          change: CHANGE,
          feed: FEED,
          webmentions: WEBMENTIONS,
          since_publish: rows({ day: INTEGER, date: Helpers::Schema::DAY, read_seconds: INTEGER, **COUNTS }),
          first_days: FIRST_DAYS,
          unique_readers: Helpers::Schema.object({ readers: MAYBE_INTEGER, final: Helpers::Schema::BOOLEAN }),
        },
      ).freeze

      include Deps[
        analytics_event_queries: "analytics.repos.analytics_event_queries",
        analytics_page_queries: "analytics.repos.analytics_page_queries",
        analytics_rollup_queries: "analytics.repos.analytics_rollup_queries",
        feed_fetch_queries: "analytics.repos.feed_fetch_queries",
        post_queries: "posts.repos.post_queries",
        post_reader_queries: "analytics.repos.post_reader_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def handle(from:, to:, path: nil, since: nil)
        at = since && Blog::TimeZone.parse_time(since)
        return invalid(since: [SINCE_REFUSAL]) if since && at.nil?

        case range(from, to)
          in Success(days) then Success(reader(days, at, path).call)
          in Failure(message) then bad_window(message)
        end
      end

      private

      def range(from, to)
        Blog::Helpers::DayWindow.days(from, to).bind do |first, last|
          if Blog::Helpers::DayWindow.too_long?(first, last)
            Failure(Blog::Helpers::DayWindow::TOO_LONG)
          else
            Success(first..last)
          end
        end
      end

      def reader(range, at, path)
        Helpers::AnalyticsReader.new(range:, at:, path:, repos:)
      end

      def repos
        {
          analytics_event_queries:, analytics_page_queries:, analytics_rollup_queries:, feed_fetch_queries:,
          post_queries:, post_reader_queries:, webmention_queries:,
        }
      end
    end
  end
end
