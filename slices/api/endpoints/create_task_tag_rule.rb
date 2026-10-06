# frozen_string_literal: true

module API
  module Endpoints
    class CreateTaskTagRule < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          pattern: TaskTagRules::PATTERN,
          provider: TaskTagRules::PROVIDER.merge(description: "where the issues come from; github when left out"),
          tags: TaskTagRules::TAGS,
        },
        required: %w[pattern tags],
      }.freeze

      REPLY = Serializers::TaskTagRule.reference

      include Deps[save_task_tag_rule: "tasks.operations.save_task_tag_rule"]

      def handle(pattern:, tags:, provider: nil)
        case save_task_tag_rule.call({ pattern:, provider:, tags: Wording.tag_list(tags) })
        in Success(rule) then Success(serialized(Serializers::TaskTagRule, rule))
        in Failure[:invalid, errors] then invalid(Wording.complaints(errors, TaskTagRules::COMPLAINTS))
        else failed(TaskTagRules::UNSAVED)
        end
      end
    end
  end
end
