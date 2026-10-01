# frozen_string_literal: true

module API
  module Endpoints
    class ReopenTask < TaskEndpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze

      include Deps[reopen_task: "tasks.operations.reopen_task"]

      def handle(id:) = settled(reopen_task.call(id), id)
    end
  end
end
