# frozen_string_literal: true

module API
  module Endpoints
    class UpdateTaskTagRule < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: TaskTagRules::ID,
          pattern: TaskTagRules::PATTERN,
          provider: TaskTagRules::PROVIDER,
          tags: TaskTagRules::TAGS.merge(description: "the whole set of tags, which replaces the old one"),
        },
        required: ["id"],
      }.freeze

      REPLY = Serializers::TaskTagRule.reference

      include Deps[
        save_task_tag_rule: "tasks.operations.save_task_tag_rule",
        task_tag_rules: "tasks.queries.task_tag_rules",
      ]

      def handle(id:, **fields)
        rule = task_tag_rules.call.find { it.id == id }
        return not_found(TaskTagRules.missing(id)) if rule.nil?

        saved(id, save_task_tag_rule.call(form(rule, fields), id:))
      end

      private

      def form(rule, fields)
        tags = fields.fetch(:tags) { rule.tags.map(&:name) }

        { pattern: fields.fetch(:pattern, rule.pattern), provider: fields[:provider], tags: Wording.tag_list(tags) }
      end

      def saved(id, result)
        case result
        in Success(rule) then Success(serialized(Serializers::TaskTagRule, rule))
        in Failure[:invalid, errors] then invalid(Wording.complaints(errors, TaskTagRules::COMPLAINTS))
        in Failure(:not_found) then not_found(TaskTagRules.missing(id))
        else failed(TaskTagRules::UNSAVED)
        end
      end
    end
  end
end
