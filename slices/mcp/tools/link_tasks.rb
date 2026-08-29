# frozen_string_literal: true

module MCP
  module Tools
    class LinkTasks < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer" },
          kind: {
            type: "string",
            enum: Blog::Types::TaskLinkKind.values,
            description: "how this task stands to the other: it blocks, is blocked_by, relates to or duplicates it",
          },
          other_id: { type: "integer" },
        },
        required: %w[id kind other_id],
      }.freeze

      description "Link one task to another. A pair takes one link, whichever way it runs"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, kind:, other_id:, server_context:)
          case link_tasks(server_context).call(id, { kind:, other_id: })
          in Success(*) then task_answer(id, server_context)
          in Failure(:not_found) then no_task(id)
          in Failure[:invalid, errors] then refuse(complaint(errors))
          else unsaved
          end
        end
      end
    end
  end
end
