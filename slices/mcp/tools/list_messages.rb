# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ListMessages < Base
      STATUS = {
        type: "string",
        enum: Blog::Types::MessageStatus.values,
        description: "every status when left out",
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::RANGE,
          page: Blog::Helpers::Paging::PAGE,
          status: STATUS,
        },
      }.freeze

      description "List the messages people sent through the contact form, newest first: " \
                  "the ID, subject, reply address, status, tags, when it came in and when a snooze ends. " \
                  "counts gives how many messages in the range sit in each status. " \
                  "Read one with read_message for its body. The subject and reply address come marked untrusted. " \
                  "#{Untrusted::WARNING}. " \
                  "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range. " \
                  "Leave both out to list every message. #{Blog::Helpers::Paging::USAGE}"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(server_context:, from: nil, to: nil, status: nil, page: 1)
          case Blog::Helpers::DayWindow.open_days(from, to)
            in Success[first, last] then listed(first, last, status, page(page, server_context), server_context)
            in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, status, page, server_context)
          found = dep(:message_queries, server_context).received_between(from: first, to: last, page:, status:)

          answer(
            from: first&.iso8601,
            to: last&.iso8601,
            counts: dep(:message_queries, server_context).count_received_between(from: first, to: last),
            messages: found.rows.map { summary(it) },
            **Blog::Helpers::Paging.fields(found),
          )
        end

        def summary(message)
          {
            id: message.id,
            subject: Untrusted.call(message.subject),
            reply_to: Untrusted.call(message.reply_to),
            status: message.status,
            tags: message.tags.map(&:name),
            received_at: message.received_at.utc.iso8601,
            snoozed_until: message.snoozed_until&.utc&.iso8601,
          }
        end
      end
    end
  end
end
