# frozen_string_literal: true

module MCP
  module Tools
    class EditDecisionOption < Base
      description "Edit one option of a decision. A field you leave out keeps what it has. Editing an option of a " \
                  "resolved or dropped decision needs a note, which goes on its timeline"
      input_schema(API::Endpoints::EditDecisionOption::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:edit_decision_option, input, server_context)
      end
    end
  end
end
