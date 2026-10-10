# frozen_string_literal: true

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
          answer(Untrusted.present(API::Serializers::Message.new(message).serializable_hash, Untrusted::MESSAGE))
        end
      end
    end
  end
end
