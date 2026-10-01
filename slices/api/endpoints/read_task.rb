# frozen_string_literal: true

module API
  module Endpoints
    class ReadTask < TaskEndpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze

      def handle(id:)
        task = task_by_id.call(id)
        return not_found(Tasks.missing(id)) if task.nil?

        task_reply(task)
      end
    end
  end
end
