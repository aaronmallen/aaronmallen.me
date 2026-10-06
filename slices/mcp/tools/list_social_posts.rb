# frozen_string_literal: true

module MCP
  module Tools
    class ListSocialPosts < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::RANGE,
          page: Blog::Paging::PAGE,
        },
        required: %w[from to],
      }.freeze

      description "List social posts over a range of days, newest first, sent and unsent alike: each with its " \
                  "status, its parts in order, each part's length and limit on each network it targets and, " \
                  "per network, how delivery stands (waiting, sending, retrying, sent or failed) with the link, " \
                  "error and engagement counts. " \
                  "A post falls on the day it went out or is set to go out, and a draft on the day it was made. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Blog::Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        include SocialPostAnswer

        def call(from:, to:, server_context:, page: 1)
          case Blog::DayWindow.days(from, to)
          in Success[first, last] then listed(first, last, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, page, server_context)
          found = dep(:social_posts_dated_between, server_context).call(from: first, to: last, page:)

          answer(
            from: first.iso8601,
            to: last.iso8601,
            social_posts: found.rows.map { social_post_entry(it, server_context) },
            **Blog::Paging.fields(found),
          )
        end
      end
    end
  end
end
