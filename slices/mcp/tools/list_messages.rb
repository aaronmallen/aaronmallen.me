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
          **Blog::DayWindow::RANGE,
          page: Blog::Paging::PAGE,
          status: STATUS,
        },
        required: %w[from to],
      }.freeze

      description "List the messages people sent through the contact form over a range, newest first: " \
                  "the ID, subject, reply address, status and when it came in. " \
                  "Read one with read_message for its body. The subject and reply address come marked untrusted. " \
                  "#{Untrusted::WARNING}. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Blog::Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, status: nil, page: 1)
          case Blog::DayWindow.days(from, to)
          in Success[first, last] then listed(first..last, status, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(range, status, page, server_context)
          found = messages_between(server_context).call(from: range.first, to: range.last, page:, status:)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            messages: found.rows.map { summary(it) },
            **Blog::Paging.fields(found),
          )
        end

        def summary(message)
          {
            id: message.id,
            subject: Untrusted.call(message.subject),
            reply_to: Untrusted.call(message.reply_to),
            status: message.status,
            received_at: message.received_at.utc.iso8601,
          }
        end
      end
    end
  end
end
