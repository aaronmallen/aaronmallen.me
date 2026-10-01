# frozen_string_literal: true

module MCP
  module Tools
    class ReadCurrentSprint < Base
      description "Read today's sprint and every task in it, in order. Opening it starts the sprint when " \
                  "today has none yet and carries in what the day before left open, as the admin does"
      input_schema(API::Endpoints::ReadCurrentSprint::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_current_sprint, input, server_context)
      end
    end
  end
end
