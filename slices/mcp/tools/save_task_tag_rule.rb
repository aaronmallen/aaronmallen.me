# frozen_string_literal: true

module MCP
  module Tools
    class SaveTaskTagRule < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer", description: "the rule to edit; leave it out to add a new one" },
          **API::Endpoints::CreateTaskTagRule::SCHEMA.fetch(:properties),
        },
      }.freeze

      description "Add a task tag rule, or edit one when you give its id. A new rule needs a pattern and tags. " \
                  "Adding a rule also tags every task already imported from a repo it matches. Editing one " \
                  "changes only what later imports take: it tags no task already imported. On an edit, a field " \
                  "you leave out keeps what it has, and tags replace the whole set"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input)
          hand_over(input.key?(:id) ? :update_task_tag_rule : :create_task_tag_rule, input, server_context)
        end
      end
    end
  end
end
