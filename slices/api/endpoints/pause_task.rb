# frozen_string_literal: true

module API
  module Endpoints
    class PauseTask < TaskEndpoint
      IDLE = "task %s is not in progress"
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze

      include Deps[reopen_task: "tasks.operations.reopen_task"]

      def handle(id:)
        task = task_by_id.call(id)
        return not_found(Tasks.missing(id)) if task.nil?
        return invalid(id: [format(IDLE, id)]) unless task.in_progress?

        settled(reopen_task.call(id), id)
      end
    end
  end
end
