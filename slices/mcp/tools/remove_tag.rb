# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTag < Base
      RULES = { true => "the task tag rule", false => "the task tag rules" }.freeze
      UNREMOVED = "could not remove the tag"

      SCHEMA = {
        additionalProperties: false,
        properties: { id: API::Schema::ID, scope: TAG_SCOPE },
        required: %w[id scope],
      }.freeze

      description "Remove one tag for good from its scope. #{TAG_KINDS}. Every record that carries the tag loses it. " \
                  "A tag that is the only tag on a task tag rule stays until the rule takes another tag or goes"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, scope:, server_context:)
          case dep(:remove_tag, server_context).call(id, scope:)
          in Success(_) then answer(id:, removed: true)
          in Failure[:last_tag_of_rules, patterns]
            refuse("tag #{id} is the only tag on #{RULES.fetch(patterns.one?)} #{patterns.join(', ')}")
          in Failure(:not_found) then refuse(API::Wording.missing("tag", id))
          else refuse(UNREMOVED)
          end
        end
      end
    end
  end
end
