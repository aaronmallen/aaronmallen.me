# frozen_string_literal: true

module MCP
  module Tools
    class MarkMessagesUnread < Base
      description "Mark up to 100 contact form messages unread at once. One that is missing marks none"
      input_schema(API::Endpoints::MarkMessagesUnread::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:mark_messages_unread, input, server_context)
      end
    end
  end
end
