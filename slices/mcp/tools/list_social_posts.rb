# frozen_string_literal: true

module MCP
  module Tools
    class ListSocialPosts < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "List social posts over a range of days, newest first, sent and unsent alike: each with its " \
                  "status, its parts in order and, per network it targets, how delivery stands (waiting, " \
                  "sending, retrying, sent or failed) with the link, error and engagement counts. " \
                  "A post falls on the day it went out or is set to go out, and a draft on the day it was made. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        include SocialPostAnswer

        def call(from:, to:, server_context:)
          first = Blog::TimeZone.parse_day(from)
          last = Blog::TimeZone.parse_day(to)
          return refuse("give from and to as days, such as 2026-01-01") unless first && last
          return refuse("from comes after to") if first > last

          found = social_posts_dated_between(server_context).call(from: first, to: last)

          answer(from: first.iso8601, to: last.iso8601, social_posts: found.map { social_post_entry(it) })
        end
      end
    end
  end
end
