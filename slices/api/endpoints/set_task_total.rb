# frozen_string_literal: true

module API
  module Endpoints
    class SetTaskTotal < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::ID, **Tasks::WORKED },
        required: ["id"],
      }.freeze

      include Deps[set_task_total: "tasks.operations.set_task_total"]

      def handle(id:, **worked)
        case set_task_total.call(id, worked)
        in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
        in result then settled(result, id)
        end
      end
    end
  end
end
