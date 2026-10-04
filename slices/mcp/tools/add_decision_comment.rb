# frozen_string_literal: true

module MCP
  module Tools
    class AddDecisionComment < Base
      description "Add a Markdown comment to a decision, open or closed, to keep your thinking as it goes"
      input_schema(API::Endpoints::AddDecisionComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:add_decision_comment, input, server_context)
      end
    end
  end
end
