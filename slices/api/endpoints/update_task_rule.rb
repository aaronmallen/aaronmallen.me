# frozen_string_literal: true

module API
  module Endpoints
    class UpdateTaskRule < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: TaskRules::ID,
          pattern: TaskRules::PATTERN,
          provider: TaskRules::PROVIDER,
          tags: TaskRules::TAGS.merge(description: "the whole set of tags, which replaces the old one"),
          projects: TaskRules::PROJECTS.merge(description: "the whole set of project IDs, which replaces the old one"),
        },
        required: ["id"],
      }.freeze

      REPLY = Serializers::TaskRule.reference

      include Deps[
        save_task_rule: "tasks.operations.save_task_rule",
        task_rules: "tasks.queries.task_rules",
      ]

      def handle(id:, **fields)
        rule = task_rules.call.find { it.id == id }
        return not_found(Wording.missing("task rule", id)) if rule.nil?

        saved(id, save_task_rule.call(form(rule, fields), id:))
      end

      private

      def form(rule, fields)
        tags = Wording.tag_list(fields.fetch(:tags) { rule.tags.map(&:name) })
        projects = fields.fetch(:projects) { rule.projects.map(&:id) }

        { pattern: fields.fetch(:pattern, rule.pattern), provider: fields[:provider], tags:, projects: }
      end

      def saved(id, result)
        case result
        in Success(rule) then Success(serialized(Serializers::TaskRule, rule))
        in Failure[:invalid, errors] then invalid(Wording.complaints(errors, TaskRules::COMPLAINTS))
        in Failure(:not_found) then not_found(Wording.missing("task rule", id))
        else failed(TaskRules::UNSAVED)
        end
      end
    end
  end
end
