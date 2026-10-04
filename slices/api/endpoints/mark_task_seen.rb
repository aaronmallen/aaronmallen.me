# frozen_string_literal: true

module API
  module Endpoints
    class MarkTaskSeen < TaskEndpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze
      UNSOURCED = "task %s has no synced issue to mark seen"

      include Deps[mark_task_seen: "tasks.operations.mark_task_seen"]

      def handle(id:)
        case mark_task_seen.call(id)
        in Failure(:unsourced) then invalid(id: [format(UNSOURCED, id)])
        in result then settled(result, id)
        end
      end
    end
  end
end
