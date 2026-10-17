# frozen_string_literal: true

module API
  module Endpoints
    class ListMailThreads < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Helpers::DayWindow::RANGE,
          page: Helpers::Paging::PAGE,
          status: {
            type: "string",
            enum: Blog::Types::MessageStatus.values,
            description: "every status when left out",
          },
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          from: Helpers::Schema.nullable(Helpers::Schema::DAY),
          to: Helpers::Schema.nullable(Helpers::Schema::DAY),
          counts: Helpers::Schema.object(
            Blog::Types::MessageStatus.values.to_h { [it.to_sym, Helpers::Schema::INTEGER] },
          ).merge(description: "how many threads in the range sit in each status"),
          mail_threads: Helpers::Schema.list(MailThreads::SUMMARY),
        },
      ).freeze

      include Deps[message_queries: "mail.repos.message_queries"]

      def handle(from: nil, to: nil, status: nil, page: 1)
        case Helpers::DayWindow.open_days(from, to)
          in Success[first, last] then Success(listed(first, last, status, page_of(page)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, status, page)
        found = message_queries.received_between(from: first, to: last, page:, status:)

        {
          **Helpers::DayWindow.range(first, last),
          counts: message_queries.count_received_between(from: first, to: last),
          mail_threads: found.rows.map { serialized(Serializers::MailThread, it) },
          **Helpers::Paging.fields(found),
        }
      end
    end
  end
end
