# frozen_string_literal: true

module API
  module Endpoints
    class CancelTask < TaskEndpoint
      CLOSED = "task %s is already done or canceled"
      SCHEMA = Schema.by_id

      include Deps[cancel_task: "tasks.operations.cancel_task"]

      def handle(id:)
        case cancel_task.call(id)
        in Failure(:closed) then invalid(id: [format(CLOSED, id)])
        in result then settled(result, id)
        end
      end
    end
  end
end
