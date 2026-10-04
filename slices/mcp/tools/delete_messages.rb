# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMessages < Base
      description "Delete up to 100 contact form messages at once. One that is missing deletes none. No undo"
      input_schema(API::Endpoints::DeleteMessages::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_messages, input, server_context)
      end
    end
  end
end
