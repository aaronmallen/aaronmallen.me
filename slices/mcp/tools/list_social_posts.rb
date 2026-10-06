# frozen_string_literal: true

module MCP
  module Tools
    class ListSocialPosts < Base
      QUEUE = {
        type: "string",
        enum: Blog::Types::SocialQueue.values,
        description: "keep only the scheduled posts (queued), the sent ones (posted) or the drafts",
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::RANGE,
          page: Blog::Paging::PAGE,
          queue: QUEUE,
        },
      }.freeze

      description "List social posts, newest first, sent and unsent alike: each with its " \
                  "status, its parts in order, each part's length and limit on each network it targets and, " \
                  "per network, how delivery stands (waiting, sending, retrying, sent or failed) with the link, " \
                  "error and engagement counts. " \
                  "A post falls on the day it went out or is set to go out, and a draft on the day it was made. " \
                  "Give queue to keep only the queued, posted or draft posts, as the admin's social screen splits " \
                  "them. counts gives how many posts in the range sit in each queue, whatever queue asks for. " \
                  "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range. " \
                  "Leave both out to list every social post. #{Blog::Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        include SocialPostAnswer

        def call(server_context:, from: nil, to: nil, queue: nil, page: 1)
          case Blog::DayWindow.open_days(from, to)
          in Success[first, last] then listed(first, last, queue, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, queue, page, server_context)
          found = dep(:social_posts_dated_between, server_context).call(from: first, to: last, page:, queue:)

          answer(
            from: first&.iso8601,
            to: last&.iso8601,
            counts: dep(:social_post_counts_between, server_context).call(from: first, to: last),
            social_posts: found.rows.map { social_post_entry(it, server_context) },
            **Blog::Paging.fields(found),
          )
        end
      end
    end
  end
end
