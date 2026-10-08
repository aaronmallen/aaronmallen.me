# frozen_string_literal: true

module API
  module Endpoints
    class CreateTaskRule < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          pattern: TaskRules::PATTERN,
          provider: TaskRules::PROVIDER.merge(description: "where the issues come from; github when left out"),
          tags: TaskRules::TAGS,
          projects: TaskRules::PROJECTS,
        },
        required: %w[pattern],
      }.freeze

      REPLY = Serializers::TaskRule.reference

      include Deps[save_task_rule: "tasks.operations.save_task_rule"]

      def handle(pattern:, provider: nil, tags: [], projects: [])
        case save_task_rule.call({ pattern:, provider:, tags: Helpers::Wording.tag_list(tags), projects: })
          in Success(rule) then Success(serialized(Serializers::TaskRule, rule))
          in Failure[:invalid, errors] then invalid(Helpers::Wording.complaints(errors, TaskRules::COMPLAINTS))
          else failed(TaskRules::UNSAVED)
        end
      end
    end
  end
end
