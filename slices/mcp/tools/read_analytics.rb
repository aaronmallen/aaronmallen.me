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
      RANKED = %i[paths referrers countries].freeze
      TOP = 25

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          path: { type: "string", description: "one page to read alone, such as #{Blog::Site::WRITING}/hello" },
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "Read the site's analytics over a range: total views, visitors and seconds read, views and " \
                  "visitors day by day, the top #{TOP} paths by views, and the top #{TOP} referrers and countries by " \
                  "visitors, each with its views and visitors. " \
                  "Totals also give reach, which counts each reader once per Chicago calendar month and adds up " \
                  "month by month: one reader on two days in a month is two visitors and one reach, and one on " \
                  "Sep 30 and Oct 1 is two reach. Reach is null when the range takes part of a month older than " \
                  "the 90 days of raw visits. " \
                  "Some older days hold no visitor count for a referrer or country: a range sums the days that " \
                  "have one, and a row with none gives visitors as null. " \
                  "A referrer of null means a direct visit, and a country of null one the site could not place. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. " \
                  "Give a path to read one page alone: its totals and its views, visitors and seconds read day by " \
                  "day, with no top lists. A page nobody visited reads as zeros. For a published post's path, " \
                  "since_publish numbers each day of the range from the Chicago day the post went out, which is " \
                  "day 1. #{DEFINITIONS}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, path: nil)
          case days(from, to)
          in Success(range) then path ? page_summary(path, range, server_context) : summary(range, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

        def numbered(days, first)
          days.map do |found|
            date = found.fetch(:day)
            { day: (date - first).to_i + 1, date: date.iso8601, **found.except(:day) }
          end
        end

        def page_summary(path, range, server_context)
          found = page_between(server_context).call(path:, from: range.first, to: range.last)
          days = found.fetch(:days)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            time_zone: Blog::TimeZone::NAME,
            path:,
            totals: totals(found, range, server_context, path:),
            days: dated(days),
            **since_publish(post_at(path, server_context), days),
          )
        end

        def post_at(path, server_context)
          slug = path.delete_prefix("#{Blog::Site::WRITING}/")
          published_post_by_slug(server_context).call(slug) unless slug == path
        end

        def since_publish(post, days)
          return {} unless post

          first = Blog::TimeZone.today(post.published_at)
          { since_publish: numbered(days.select { it.fetch(:day) >= first }, first) }
        end

        def summary(range, server_context)
          found = analytics_between(server_context).call(from: range.first, to: range.last)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            time_zone: Blog::TimeZone::NAME,
            totals: totals(found, range, server_context),
            days: dated(found.fetch(:days)),
            **RANKED.to_h { [it, found.fetch(it).take(TOP)] },
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
