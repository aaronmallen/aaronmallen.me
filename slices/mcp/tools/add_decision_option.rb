# frozen_string_literal: true

module MCP
  module Tools
    class AddDecisionOption < Base
      description "Add an option to an open decision, with a title and a Markdown body"
      input_schema(API::Endpoints::AddDecisionOption::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:add_decision_option, input, server_context)
      end
    end
  end
end
