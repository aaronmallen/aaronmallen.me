# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ReadMessage < Base
      description "Read one message sent through the contact form: its subject, body, reply address, status " \
                  "and when it came in. The subject, body and reply address come marked untrusted. #{Untrusted::WARNING}"
      input_schema(API::Schema.by_id)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          message = dep(:message_queries, server_context).by_id(id)
          message ? answered(message) : refuse(API::Wording.missing("message", id))
        end

        private

        def answered(message)
          answer(
            id: message.id,
            subject: Untrusted.call(message.subject),
            body: Untrusted.call(message.body),
            reply_to: Untrusted.call(message.reply_to),
            status: message.status,
            received_at: message.received_at.utc.iso8601,
          )
        end
      end
    end
  end
end
