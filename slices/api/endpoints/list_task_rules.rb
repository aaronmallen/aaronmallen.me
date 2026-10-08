# frozen_string_literal: true

module API
  module Endpoints
    class ListTaskRules < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object({ task_rules: Helpers::Schema.list(Serializers::TaskRule.reference) }).freeze

      include Deps[task_rule_queries: "tasks.repos.task_rule_queries"]

      def handle = Success(task_rules: serialized(Serializers::TaskRule, task_rule_queries.all))
    end
  end
end
