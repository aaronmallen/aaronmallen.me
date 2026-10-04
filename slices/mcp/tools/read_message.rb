# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ReadMessage < Base
      SCHEMA = { additionalProperties: false, properties: { id: API::Schema::ID }, required: ["id"] }.freeze

      description "Read one message sent through the contact form: its subject, body, reply address, status " \
                  "and when it came in. The subject, body and reply address come marked untrusted. #{Untrusted::WARNING}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          message = message_by_id(server_context).call(id)
          return refuse("no message has the ID #{id}") if message.nil?

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
