# frozen_string_literal: true

module API
  module Endpoints
    class ListWebmentions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::RANGE,
          page: Blog::Paging::PAGE,
          status: {
            type: "string",
            enum: Blog::Types::WebmentionStatus.values,
            description: "only webmentions in this status; every status when you leave it out",
          },
          post_id: Webmentions::ID.merge(description: "only the webmentions this post got; every post's when you " \
                                                      "leave it out"),
        },
        required: %w[from to],
      }.freeze

      REPLY = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
          time_zone: Schema::STRING,
          webmentions: Schema.list(Serializers::Webmention.reference),
          partial: Schema::BOOLEAN,
        },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", webmentions_received_in: "social.queries.webmentions_received_in"]

      def handle(from:, to:, status: nil, post_id: nil, page: 1)
        case Blog::DayWindow.days(from, to)
        in Success[first, last] then Success(listed(first, last, status, post_id, page_of(page)))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(first, last, status, post_id, page)
        found = webmentions_received_in.call(from: first, to: last, page:, status:, post_id:)

        {
          from: first.iso8601,
          to: last.iso8601,
          time_zone: Blog::TimeZone::NAME,
          webmentions: serialized(Serializers::Webmention, found.rows),
          **Blog::Paging.fields(found),
        }
      end
    end
  end
end
