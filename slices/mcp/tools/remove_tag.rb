# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTag < Base
      UNREMOVED = "could not remove the tag"

      SCHEMA = {
        additionalProperties: false,
        properties: { id: { type: "integer" }, scope: TAG_SCOPE },
        required: %w[id scope],
      }.freeze

      description "Remove one tag for good from its scope. Public tags go on posts and projects; private tags go " \
                  "on journal entries and tasks. Every record that carries the tag loses it"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, scope:, server_context:)
          case remove_tag(server_context).call(id, scope:)
          in Success(_) then answer(id:, removed: true)
          in Failure(:not_found) then refuse("no tag has the ID #{id}")
          else refuse(UNREMOVED)
          end
        end
      end
    end
  end
end
