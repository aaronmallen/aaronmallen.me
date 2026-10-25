# frozen_string_literal: true

module API
  module Endpoints
    class CompleteTask < TaskEndpoint
      SHOWN = %i[completed_at worked_seconds].freeze
      SHOWS_TASKS = true

      REPLY = Helpers::Schema.object(BRIEF.merge(Serializers::Task::SCHEMA[:properties].slice(*SHOWN))).freeze

      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::TASK, **Tasks::WORKED },
        required: ["id"],
      }.freeze

      include Deps[complete_task: "tasks.operations.complete_task"]

      def handle(id:, **worked)
        case complete_task.call(id, worked: worked.empty? ? nil : worked)
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          in result then settled(result, id, SHOWN)
        end
      end
    end
  end
end
