# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTag < Base
      UNREMOVED = "could not remove the tag"

      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Remove one tag for good. A tag any record still carries stays; list_tags says which do"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          tag = every_tag(server_context).find { it.id == id }
          return refuse("no tag has the ID #{id}") unless tag

          case remove_tag(server_context).call(id, scope: tag.scope)
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
