# frozen_string_literal: true

module API
  module Endpoints
    class PauseTask < TaskEndpoint
      IDLE = "task %s is not in progress"
      SCHEMA = Tasks::BY_ID
      SHOWN = %i[worked_seconds].freeze
      SHOWS_TASKS = true

      REPLY = Helpers::Schema.object(BRIEF.merge(Serializers::Task::SCHEMA[:properties].slice(*SHOWN))).freeze

      include Deps[pause_task: "tasks.operations.pause_task"]

      def handle(id:)
        case pause_task.call(id)
          in Failure(:idle) then invalid(id: [format(IDLE, id)])
          in result then settled(result, id, SHOWN)
        end
      end
    end
  end
end
