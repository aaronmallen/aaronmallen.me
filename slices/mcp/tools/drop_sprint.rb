# frozen_string_literal: true

module MCP
  module Tools
    class DropSprint < Base
      description "Drop a sprint that has not started yet. Its tasks go back to next"
      input_schema(API::Endpoints::DropSprint::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:drop_sprint, input, server_context)
      end
    end
  end
end
