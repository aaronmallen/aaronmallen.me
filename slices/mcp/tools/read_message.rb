# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ReadMessage < Base
      description "Read one message sent through the contact form: its subject, body, reply address, status, " \
                  "tags, when it came in and when a snooze ends. " \
                  "The subject, body and reply address come marked untrusted. #{Untrusted::WARNING}"
      input_schema(API::Helpers::Schema.by_id)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(id:, server_context:)
          message = dep(:message_queries, server_context).by_id(id)
          message ? answered(message) : refuse(API::Helpers::Wording.missing("message", id))
        end

        private

        def answered(message)
          answer(
            id: message.id,
            subject: Untrusted.call(message.subject),
            body: Untrusted.call(message.body),
            reply_to: Untrusted.call(message.reply_to),
            status: message.status,
            tags: message.tags.map(&:name),
            received_at: stamp(message.received_at),
            snoozed_until: stamp(message.snoozed_until),
          )
        end

        def stamp(time) = time&.utc&.iso8601
      end
    end
  end
end
