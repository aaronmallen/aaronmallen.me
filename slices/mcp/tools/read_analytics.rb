# frozen_string_literal: true

module MCP
  module Tools
    class ReadAnalytics < Base
      DEFINITIONS = "A view is one page load. A visitor is a hash of the address and user agent that changes " \
                    "each day and sets no cookie, so visitors add up day by day and one reader on two days counts " \
                    "twice. A bounce is a visitor with one view that day across the whole site. read_seconds is " \
                    "the time a page sat on screen in a visible tab, capped at 20 minutes a view. Nothing counts " \
                    "while the owner is signed in, or from a known bot or a client with no user agent. Days run " \
                    "on #{Blog::TimeZone::NAME} time, and each answer names it as time_zone".freeze
      RAW_DAYS = Analytics::Repos::AnalyticsEventQueries::RETENTION_DAYS
      RAW_REFUSAL = "hours, since, read_spread and navigation read raw visits, which the site keeps for " \
                    "#{RAW_DAYS} days; start from or since inside them to get these. The daily counts still " \
                    "hold".freeze
      READ_THROUGH_DEPTH, READ_THROUGH_SECONDS =
        Hanami.app.settings.analytics.values_at(:read_through_scroll_depth, :read_through_seconds)
      REF = Analytics::Operations::TagRef::KEY
      SINCE_REFUSAL = "give since as an ISO 8601 time, such as 2026-10-01T09:00:00-05:00"
      TOP = 25

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

      description "Read the site's analytics over a range: total views, visitors and seconds read, views and " \
                  "visitors day by day, the top #{TOP} paths by views, and the top #{TOP} referrers and countries by " \
                  "visitors, each with its views and visitors. " \
                  "A read-through is a visitor who scrolled at least #{READ_THROUGH_DEPTH}% " \
                  "down a page and read it for at least #{READ_THROUGH_SECONDS} seconds, counted " \
                  "once per page and day by the daily hash. Totals give read_throughs across the range, and each " \
                  "top path gives its own. Days rolled up before the site counted read-throughs add none. " \
                  "weekday_hours gives the visitors in each #{Blog::TimeZone::NAME} hour of each weekday over " \
                  "the last #{RAW_DAYS} days to today, whatever the range: 24 rows, one per hour from 0, each " \
                  "with a count for monday through sunday, and the from, to and time_zone of the window. A " \
                  "visitor counts once a cell by the daily hash, so one reader on two Mondays at 9 counts twice. " \
                  "sources gives the top #{TOP} ref tags by visitors, each with its views and visitors: a visit " \
                  "to a link that carries ?#{REF}=<source> counts under that source, so the " \
                  "site's crossposts (such as mastodon) and its feed (feed) credit where a reader tapped, and " \
                  "hand-typed tags count too. sources leaves out visits with no tag. " \
                  "devices gives views and visitors by device class, ranked by visitors: one of " \
                  "#{Blog::Types::DeviceClass.values.join(', ')}, worked out from the user agent when the view " \
                  "came in. in-app means a browser inside another app, such as Mastodon, Bluesky or Reddit, which " \
                  "often sends no referrer. Views from before the site kept a class are left out. " \
                  "Totals also give reach, which counts each reader once per #{Blog::TimeZone::NAME} calendar " \
                  "month and adds up month by month: one reader on two days in a month is two visitors and one " \
                  "reach, and one on " \
                  "Sep 30 and Oct 1 is two reach. Reach is null when the range takes part of a month older than " \
                  "the #{RAW_DAYS} days of raw visits. " \
                  "change sets the range's views against the range of the same length just before it: that " \
                  "range's from, to and views, and percent, the rise or fall in views as a whole percent of its " \
                  "views, null when it had none. " \
                  "feed counts the people who follow the site's feeds: days gives subscribers each day, the count " \
                  "feed aggregators such as Feedly report plus the other readers that fetched a feed; latest " \
                  "gives that count for the last day of the range, or yesterday when the range runs to today; " \
                  "and aggregators gives each aggregator's latest count in the range, summed across the feeds, " \
                  "most first. webmentions gives pending, the webmentions waiting for review now whatever the " \
                  "range; received, the webmentions that came in over the range in any state; and posts, the " \
                  "top #{TOP} posts by webmentions received over the range, each with its post_id, title and " \
                  "received. " \
                  "Some older days hold no visitor count for a referrer or country: a range sums the days that " \
                  "have one, and a row with none gives visitors as null. " \
                  "A referrer of null means a direct visit, and a country of null one the site could not place. " \
                  "Each country gives its country_code and its English country_name, which is null for visits " \
                  "from before the site kept names. " \
                  "Each top path gives its latest page title, which the visitor's browser sends, marked untrusted. " \
                  "#{Untrusted::WARNING}. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range, which runs at most " \
                  "#{Blog::Helpers::DayWindow::LONGEST} days. " \
                  "Give a path to read one page alone: its totals and its views, visitors and seconds read day by " \
                  "day, its top #{TOP} referrers, countries and sources by visitors, each with its views, its " \
                  "devices, and its top #{TOP} outbound clicks, with no top paths, weekday_hours, change, feed or " \
                  "webmentions. Its totals give its own read_throughs and its bounces. clicks counts the times " \
                  "a reader followed a link off the page, by link_host and link_path, most first. A " \
                  "page's referrers and countries always give visitors. A page nobody visited reads as zeros. " \
                  "For a published post's path, since_publish numbers each day of the range from the " \
                  "#{Blog::TimeZone::NAME} day the post went out, which is day 1. The post also gets first_days " \
                  "and unique_readers, whatever the range. first_days gives its visitors on each of its first " \
                  "#{Analytics::Repos::AnalyticsPageQueries::FIRST_DAYS} days, day 1 first, up to today, and " \
                  "median, the middle visitors on each of those days across the posts the site counted from " \
                  "their first day, for comparison. unique_readers gives readers, the people who viewed the post " \
                  "in the 12 months after it went out, each counted once by a hash kept for those months, and " \
                  "final, true once the count can no longer change. readers is null for a post that went out " \
                  "too long before the site began counting. " \
                  "A page's scroll gives the views that tracked scrolling and, for each depth of " \
                  "#{Blog::Types::ScrollDepth.values.select(&:positive?).join(', ')}%, the views that scrolled at " \
                  "least that far and their share of those views, null when no view tracked it. Scroll depth is " \
                  "kept forever, and views from before the site tracked it are left out. " \
                  "hours gives views and visitors for each #{Blog::TimeZone::NAME} hour of the range that had a " \
                  "view, oldest first, each named by its start with its offset; a visitor counts once an hour by " \
                  "the daily hash. Give since as an ISO 8601 time to count only views from then: hours start " \
                  "there, and since gives the views, visitors and seconds read from then to the end of the range, " \
                  "with the top #{TOP} paths by views for the whole site. A since with no offset reads as " \
                  "#{Blog::TimeZone::NAME} time. " \
                  "read_spread splits the views from the later of from and since to the end of the range by " \
                  "read_seconds: each bucket gives the views that read from its from to its to seconds, both ends " \
                  "inside, and the first bucket, 0 to 0, holds the views with no read. median is the middle " \
                  "read_seconds of the views that read, null when none did. " \
                  "Navigation follows each visitor's views in order, from the later of from and since to the " \
                  "end of the range. entry_pages gives the top #{TOP} pages " \
                  "visitors landed on first and exit_pages the top #{TOP} they saw last, each with the visitors " \
                  "who did, counted once per visitor and day by the daily hash; a visitor with one view counts " \
                  "in both. With a path, internal_referrers gives the top #{TOP} pages on the site that sent " \
                  "readers to it, by visitors, each with its views; the site keeps the path of a referrer only " \
                  "when it is the site itself, and an outside referrer stays a host in referrers. " \
                  "Views from before the site kept referring paths are left out. " \
                  "Hours, since, read_spread and navigation read raw visits, kept for #{RAW_DAYS} days: when the " \
                  "later of from and since falls before them, the answer leaves them out and says why in " \
                  "refused, and the daily counts still come back. With a path, hours, since and read_spread " \
                  "count that page alone. #{DEFINITIONS}"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(from:, to:, server_context:, path: nil, since: nil)
          reader = parse_since(since).bind do |at|
            range(from, to).fmap { AnalyticsReader.new(range: it, at:, path:, context: server_context) }
          end

          case reader
            in Success(found) then answer(found.call)
            in Failure(message) then refuse(message)
          end
        end

        private

        def parse_since(since)
          return Success(nil) unless since

          at = Blog::TimeZone.parse_time(since)
          at ? Success(at) : Failure(SINCE_REFUSAL)
        end

        def range(from, to)
          Blog::Helpers::DayWindow.days(from, to).bind do |first, last|
            too_long?(first, last) ? Failure(Blog::Helpers::DayWindow::TOO_LONG) : Success(first..last)
          end
        end
      end
    end
  end
end
