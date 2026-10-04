# frozen_string_literal: true

module MCP
  module Tools
    class MarkMessagesRead < Base
      description "Mark up to 100 contact form messages read at once. One that is missing marks none"
      input_schema(API::Endpoints::MarkMessagesRead::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:mark_messages_read, input, server_context)
      end
    end
  end
end
