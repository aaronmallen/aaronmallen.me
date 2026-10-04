# frozen_string_literal: true

module API
  module Endpoints
    class CompleteTask < TaskEndpoint
      CLOSED = "task %s is already done or canceled"
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::ID, **Tasks::WORKED },
        required: ["id"],
      }.freeze

      include Deps[complete_task: "tasks.operations.complete_task"]

      def handle(id:, **worked)
        case complete_task.call(id, worked: worked.empty? ? nil : worked)
        in Failure(:closed) then invalid(id: [format(CLOSED, id)])
        in Failure[:invalid, errors] then rejected(errors)
        in result then settled(result, id)
        end
      end
    end
  end
end
