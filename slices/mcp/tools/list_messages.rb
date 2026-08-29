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
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          status: STATUS,
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "List the messages people sent through the contact form over a range, newest first: " \
                  "the ID, subject, reply address, status and when it came in. " \
                  "Read one with read_message for its body. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, status: nil)
          case days(from, to)
          in Success(range) then listed(range, status, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(range, status, server_context)
          found = messages_between(server_context).call(from: range.first, to: range.last, status:)

          answer(from: range.first.iso8601, to: range.last.iso8601, messages: found.map { summary(it) })
        end

        def summary(message)
          {
            id: message.id,
            subject: message.subject,
            reply_to: message.reply_to,
            status: message.status,
            received_at: message.received_at.utc.iso8601,
          }
        end
      end
    end
  end
end
