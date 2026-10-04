# frozen_string_literal: true

module MCP
  module Tools
    class EditDecision < Base
      description "Edit a decision's title or problem statement. A field you leave out keeps what it has. Changing " \
                  "the problem of a resolved or dropped decision needs a note, which goes on its timeline"
      input_schema(API::Endpoints::EditDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:edit_decision, input, server_context)
      end
    end
  end
end
