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
                  "on journal entries and tasks. A tag any record still carries stays; list_tags says which do"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, scope:, server_context:)
          case remove_tag(server_context).call(id, scope:)
          in Success(_) then answer(id:, removed: true)
          in Failure[:in_use, held] then refuse(kept(held))
          in Failure(:not_found) then refuse("no tag has the ID #{id}")
          else refuse(UNREMOVED)
          end
        end

        private

        def kept(held) = held == 1 ? "kept: 1 record still carries it" : "kept: #{held} records still carry it"
      end
    end
  end
end
