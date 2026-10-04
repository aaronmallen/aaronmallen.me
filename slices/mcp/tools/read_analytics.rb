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
      PAGE_RANKED = %i[referrers countries].freeze
      RANKED = %i[paths referrers countries sources devices].freeze
      RAW_REFUSAL = "hours, since, read_spread and navigation read raw visits, which the site keeps for 90 days; " \
                    "start from or since inside them to get these. The daily counts still hold"
      SINCE_REFUSAL = "give since as an ISO 8601 time, such as 2026-10-01T09:00:00-05:00"
      TOP = 25

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::RANGE,
          path: { type: "string", description: "one page to read alone, such as #{Blog::Site::WRITING}/hello" },
          since: { type: "string", description: "an ISO 8601 time, such as 2026-10-01T09:00:00-05:00" },
        },
        required: %w[from to],
      }.freeze

      description "Read the site's analytics over a range: total views, visitors and seconds read, views and " \
                  "visitors day by day, the top #{TOP} paths by views, and the top #{TOP} referrers and countries by " \
                  "visitors, each with its views and visitors. " \
                  "A read-through is a visitor who scrolled at least #{Analytics::ReadThrough::SCROLL_DEPTH}% " \
                  "down a page and read it for at least #{Analytics::ReadThrough::READ_SECONDS} seconds, counted " \
                  "once per page and day by the daily hash. Totals give read_throughs across the range, and each " \
                  "top path gives its own. Days rolled up before the site counted read-throughs add none. " \
                  "#{WeekdayGrid::DESCRIPTION}" \
                  "sources gives the top #{TOP} ref tags by visitors, each with its views and visitors: a visit " \
                  "to a link that carries ?#{Analytics::Ref::KEY}=<source> counts under that source, so the " \
                  "site's crossposts (such as mastodon) and its feed (feed) credit where a reader tapped, and " \
                  "hand-typed tags count too. sources leaves out visits with no tag. " \
                  "devices gives views and visitors by device class, ranked by visitors: one of " \
                  "#{Analytics::Device::CLASSES.join(', ')}, worked out from the user agent when the view came in. " \
                  "in-app means a browser inside another app, such as Mastodon, Bluesky or Reddit, which often " \
                  "sends no referrer. Views from before the site kept a class are left out. " \
                  "Totals also give reach, which counts each reader once per Chicago calendar month and adds up " \
                  "month by month: one reader on two days in a month is two visitors and one reach, and one on " \
                  "Sep 30 and Oct 1 is two reach. Reach is null when the range takes part of a month older than " \
                  "the 90 days of raw visits. " \
                  "Some older days hold no visitor count for a referrer or country: a range sums the days that " \
                  "have one, and a row with none gives visitors as null. " \
                  "A referrer of null means a direct visit, and a country of null one the site could not place. " \
                  "Each top path gives its latest page title, which the visitor's browser sends, marked untrusted. " \
                  "#{Untrusted::WARNING}. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range, which runs at most " \
                  "#{Blog::DayWindow::LONGEST} days. " \
                  "Give a path to read one page alone: its totals and its views, visitors and seconds read day by " \
                  "day, its top #{TOP} referrers, countries and sources by visitors, each with its views, and " \
                  "its devices, with no top paths or weekday_hours. Its totals give its own read_throughs. A " \
                  "page's referrers and countries always give visitors. A page nobody visited reads as zeros. " \
                  "For a published post's path, since_publish numbers each day of " \
                  "the range from the Chicago day the post went out, which is day 1. " \
                  "A page's scroll gives the views that tracked scrolling and, for each depth of " \
                  "#{Analytics::Scroll::DEPTHS.join(', ')}%, the views that scrolled at least that far and their " \
                  "share of those views, null when no view tracked it. Scroll depth is kept forever, and views " \
                  "from before the site tracked it are left out. " \
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
                  "Hours, since, read_spread and navigation read raw visits, kept for 90 days: when the later of " \
                  "from and since falls before them, the answer leaves them out and says why in refused, and the " \
                  "daily counts still come back. With a path, hours, since and read_spread count that page " \
                  "alone. #{DEFINITIONS}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, path: nil, since: nil)
          at = Blog::TimeZone.parse_time(since) if since
          return refuse(SINCE_REFUSAL) if since && !at

          case Blog::DayWindow.days(from, to)
          in Success[first, last] if too_long?(first, last) then refuse_long_range
          in Success[first, last] then read(first..last, at, path, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def breakdowns(range, path, server_context)
          { sources: sources(range, path, server_context), devices: devices(range, path, server_context) }
        end

        def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

        def devices(range, path, server_context)
          devices_between(server_context).call(from: range.first, to: range.last, path:)
        end

        def numbered(days, first)
          days.map do |found|
            date = found.fetch(:day)
            { day: (date - first).to_i + 1, date: date.iso8601, **found.except(:day) }
          end
        end

        def page(path, range, server_context)
          found = page_between(server_context).call(path:, from: range.first, to: range.last)
          read_throughs = read_throughs(range, server_context).fetch(path, 0)

          found.merge(totals: found.fetch(:totals).merge(read_throughs:))
        end

        def page_ranked(found, range, path, server_context)
          {
            **PAGE_RANKED.to_h { [it, found.fetch(it).take(TOP)] },
            **breakdowns(range, path, server_context),
            scroll: scroll_depths_between(server_context).call(path:, from: range.first, to: range.last),
          }
        end

        def page_summary(path, range, at, server_context)
          found = page(path, range, server_context)
          days = found.fetch(:days)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            time_zone: Blog::TimeZone::NAME,
            path:,
            totals: totals(found, range, server_context, path:),
            days: dated(days),
            **page_ranked(found, range, path, server_context),
            **raw(range, at, path, server_context),
            **since_publish(post_at(path, server_context), days),
          )
        end

        def post_at(path, server_context)
          slug = path.delete_prefix("#{Blog::Site::WRITING}/")
          published_post_by_slug(server_context).call(slug) unless slug == path
        end

        def ranked(range, server_context)
          found = analytics_between(server_context).call(from: range.first, to: range.last)
          read_throughs = read_throughs(range, server_context)

          found.merge(
            breakdowns(range, nil, server_context),
            paths: found.fetch(:paths).map { ranked_path(it, read_throughs) },
            totals: found.fetch(:totals).merge(read_throughs: read_throughs.values.sum),
          )
        end

        def ranked_path(found, read_throughs)
          found.merge(title: Untrusted.call(found[:title]), read_throughs: read_throughs.fetch(found.fetch(:path), 0))
        end

        def raw(range, at, path, server_context)
          window = raw_window(range, at, path)
          found = hourly_between(server_context).call(**window)
          return { refused: RAW_REFUSAL } unless found

          hours = found.fetch(:hours).map { it.merge(hour: stamped(it.fetch(:hour))) }
          read_spread = read_spread_between(server_context).call(**window)
          timed = at ? { hours:, read_spread:, since: since_counts(found, at) } : { hours:, read_spread: }
          timed.merge(navigation_between(server_context).call(**window).transform_values { it.take(TOP) })
        end

        def raw_window(range, at, path)
          { from: [Blog::TimeZone.day_start(range.first), at].compact.max,
            to: Blog::TimeZone.day_start(range.last + 1), path: }
        end

        def read(range, at, path, server_context)
          path ? page_summary(path, range, at, server_context) : summary(range, at, server_context)
        end

        def read_throughs(range, server_context)
          read_throughs_between(server_context).call(from: range.first, to: range.last)
        end

        def since_counts(found, at)
          top = found.slice(:paths).transform_values { it.take(TOP) }

          { at: stamped(at), **found.fetch(:totals), **top }
        end

        def since_publish(post, days)
          return {} unless post

          first = Blog::TimeZone.today(post.published_at)
          { since_publish: numbered(days.select { it.fetch(:day) >= first }, first) }
        end

        def sources(range, path, server_context)
          sources_between(server_context).call(from: range.first, to: range.last, path:).take(TOP)
        end

        def stamped(time) = Blog::TimeZone.local(time).iso8601

        def summary(range, at, server_context)
          found = ranked(range, server_context)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            time_zone: Blog::TimeZone::NAME,
            totals: totals(found, range, server_context),
            days: dated(found.fetch(:days)),
            **raw(range, at, nil, server_context),
            **RANKED.to_h { [it, found.fetch(it).take(TOP)] },
            weekday_hours: WeekdayGrid.call(weekday_hours(server_context)),
          )
        end

        def totals(found, range, server_context, path: nil)
          reach = reach_between(server_context).call(from: range.first, to: range.last, path:)

          found.fetch(:totals).merge(reach:)
        end
      end
    end
  end
end
