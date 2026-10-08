# frozen_string_literal: true

module API
  module Endpoints
    class ListWebmentions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::RANGE,
          page: Blog::Helpers::Paging::PAGE,
          status: {
            type: "string",
            enum: Blog::Types::WebmentionStatus.values,
            description: "only webmentions in this status; every status when you leave it out",
          },
          post_id: Webmentions::ID.merge(description: "only the webmentions this post got; every post's when you " \
                                                      "leave it out"),
        },
      }.freeze

      COUNTS = Helpers::Schema.object(
        Blog::Types::WebmentionStatus.values.to_h { [it.to_sym, Helpers::Schema::INTEGER] },
      ).merge(
        description: "how many webmentions in the range, and for the post when given, sit in each status",
      ).freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema.nullable(Helpers::Schema::DAY),
          to: Helpers::Schema.nullable(Helpers::Schema::DAY),
          time_zone: Helpers::Schema::STRING,
          counts: COUNTS,
          webmentions: Helpers::Schema.list(Serializers::Webmention.reference),
          partial: Helpers::Schema::BOOLEAN,
        },
        optional: { next_page: Helpers::Schema::INTEGER },
      ).freeze

      include Deps[
        "settings",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def handle(from: nil, to: nil, status: nil, post_id: nil, page: 1)
        case Blog::Helpers::DayWindow.open_days(from, to)
          in Success[first, last] then Success(listed(first, last, status, post_id, page_of(page)))
          in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(first, last, status, post_id, page)
        found = webmention_queries.received_in(from: first, to: last, page:, status:, post_id:)

        {
          from: first&.iso8601,
          to: last&.iso8601,
          time_zone: Blog::TimeZone::NAME,
          counts: webmention_queries.count_received_in(from: first, to: last, post_id:),
          webmentions: serialized(Serializers::Webmention, found.rows),
          **Blog::Helpers::Paging.fields(found),
        }
      end
    end
  end
end
