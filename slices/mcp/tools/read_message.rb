# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ReadMessage < Base
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Read one message sent through the contact form: its subject, body, reply address, status " \
                  "and when it came in"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          message = message_by_id(server_context).call(id)
          return refuse("no message has the ID #{id}") if message.nil?

          answer(
            id: message.id,
            subject: message.subject,
            body: message.body,
            reply_to: message.reply_to,
            status: message.status,
            received_at: message.received_at.utc.iso8601,
          )
        end
      end
    end
  end
end
