# frozen_string_literal: true

module MCP
  module Tools
    class SaveTaskRule < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID.merge(description: "the rule to edit; leave it out to add a new one"),
          **API::Endpoints::CreateTaskRule::SCHEMA.fetch(:properties),
        },
      }.freeze

      description "Add a task rule, or edit one when you give its id. A new rule needs a pattern and tags, projects " \
                  "or both, and is a GitHub rule unless you name Linear as its provider. A rule matches only issues " \
                  "from its own provider. Each issue imported later takes the rule's tags and links to its projects. " \
                  "Adding a rule also tags and links every task already imported that it matches. Editing one " \
                  "changes only what later imports take: it tags or links no task already imported. On an edit, a " \
                  "field you leave out keeps what it has, and tags or projects replace the whole set"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(server_context:, **input)
          hand_over(input.key?(:id) ? :update_task_rule : :create_task_rule, input, server_context)
        end
      end
    end
  end
end
