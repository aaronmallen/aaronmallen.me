# frozen_string_literal: true

module API
  module Endpoints
    class ListSocialPosts < SocialPostEndpoint
      COUNTED = "how many posts in the range sit in each queue, whatever queue asks for"
      COUNTS = Schema.object(Blog::Types::SocialQueue.values.to_h { [it.to_sym, Schema::INTEGER] }).merge(
        description: COUNTED,
      ).freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::RANGE,
          page: Blog::Paging::PAGE,
          queue: {
            type: "string",
            enum: Blog::Types::SocialQueue.values,
            description: "keep only the scheduled posts (queued), the sent ones (posted) or the drafts",
          },
        },
      }.freeze

      REPLY = Schema.object(
        {
          from: Schema.nullable(Schema::DAY),
          to: Schema.nullable(Schema::DAY),
          counts: COUNTS,
          social_posts: Schema.list(SocialPostEndpoint::REPLY),
          partial: Schema::BOOLEAN,
        },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings"]

      def handle(from: nil, to: nil, queue: nil, page: 1)
        case Blog::DayWindow.open_days(from, to)
          in Success[first, last] then Success(listed(first, last, queue, page))
          in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(first, last, queue, number)
        found = social_post_queries.dated_between(from: first, to: last, page: page_of(number), queue:)

        {
          from: first&.iso8601,
          to: last&.iso8601,
          counts: social_post_queries.count_dated_between(from: first, to: last),
          social_posts: found.rows.map { answered(it) },
          **Blog::Paging.fields(found),
        }
      end
    end
  end
end
