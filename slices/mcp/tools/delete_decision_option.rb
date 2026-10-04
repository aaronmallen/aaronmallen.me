# frozen_string_literal: true

module MCP
  module Tools
    class DeleteDecisionOption < Base
      description "Delete one option of a decision. The option a decision was resolved with stays until it reopens. " \
                  "This cannot be undone"
      input_schema(API::Endpoints::DeleteDecisionOption::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_decision_option, input, server_context)
      end
    end
  end
end
