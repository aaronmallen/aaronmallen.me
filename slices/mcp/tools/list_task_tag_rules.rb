# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskTagRules < Base
      description "List the task tag rules by pattern, each with its ID, pattern and tags. A rule gives its private " \
                  "tags to every issue imported from a repo its pattern matches"
      input_schema(API::Endpoints::ListTaskTagRules::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_task_tag_rules, input, server_context)
      end
    end
  end
end
