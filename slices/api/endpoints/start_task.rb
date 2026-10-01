# frozen_string_literal: true

module API
  module Endpoints
    class StartTask < TaskEndpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze

      include Deps[start_task: "tasks.operations.start_task"]

      def handle(id:) = settled(start_task.call(id), id)
    end
  end
end
