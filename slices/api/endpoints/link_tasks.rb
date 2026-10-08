# frozen_string_literal: true

module API
  module Endpoints
    class LinkTasks < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          kind: {
            type: "string",
            enum: Blog::Types::TaskLinkKind.values,
            description: "how this task stands to the other: it blocks, is blocked_by, relates to or duplicates it",
          },
          other_id: Tasks::ID,
        },
        required: %w[id kind other_id],
      }.freeze

      include Deps[link_tasks: "tasks.operations.link_tasks"]

      def handle(id:, kind:, other_id:)
        case link_tasks.call(id, { kind:, other_id: })
          in Success(*) then answered(id)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("task", id))
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
