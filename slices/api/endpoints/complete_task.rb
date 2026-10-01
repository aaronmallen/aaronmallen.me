# frozen_string_literal: true

module API
  module Endpoints
    class CompleteTask < TaskEndpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze

      include Deps[complete_task: "tasks.operations.complete_task"]

      def handle(id:) = settled(complete_task.call(id), id)
    end
  end
end
