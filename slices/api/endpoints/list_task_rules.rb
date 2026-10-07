# frozen_string_literal: true

module API
  module Endpoints
    class ListTaskRules < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.object({ task_rules: Schema.list(Serializers::TaskRule.reference) }).freeze

      include Deps[task_rules: "tasks.queries.task_rules"]

      def handle = Success(task_rules: serialized(Serializers::TaskRule, task_rules.call))
    end
  end
end
