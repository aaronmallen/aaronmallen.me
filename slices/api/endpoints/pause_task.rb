# frozen_string_literal: true

module API
  module Endpoints
    class PauseTask < TaskEndpoint
      IDLE = "task %s is not in progress"
      SCHEMA = Helpers::Schema.by_id

      include Deps[pause_task: "tasks.operations.pause_task"]

      def handle(id:)
        case pause_task.call(id)
          in Failure(:idle) then invalid(id: [format(IDLE, id)])
          in result then settled(result, id)
        end
      end
    end
  end
end
