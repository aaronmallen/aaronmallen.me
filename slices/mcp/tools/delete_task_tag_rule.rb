# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTaskTagRule < Base
      description "Delete one task tag rule for good. Every task keeps the tags it has, and later imports stop " \
                  "taking the rule's tags"
      input_schema(API::Endpoints::DeleteTaskTagRule::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_task_tag_rule, input, server_context)
      end
    end
  end
end
