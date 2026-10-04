# frozen_string_literal: true

module MCP
  module Tools
    class EditDecisionComment < Base
      description "Replace the body of one comment on a decision"
      input_schema(API::Endpoints::EditDecisionComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:edit_decision_comment, input, server_context)
      end
    end
  end
end
