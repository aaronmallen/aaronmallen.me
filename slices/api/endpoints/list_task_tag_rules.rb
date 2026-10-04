# frozen_string_literal: true

module API
  module Endpoints
    class ListTaskTagRules < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.object({ task_tag_rules: Schema.list(Serializers::TaskTagRule.reference) }).freeze

      include Deps[task_tag_rules: "tasks.queries.task_tag_rules"]

      def handle = Success(task_tag_rules: serialized(Serializers::TaskTagRule, task_tag_rules.call))
    end
  end
end
