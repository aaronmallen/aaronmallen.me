# frozen_string_literal: true

module API
  module Endpoints
    class CancelTask < TaskEndpoint
      SCHEMA = Schema.by_id

      include Deps[cancel_task: "tasks.operations.cancel_task"]

      def handle(id:) = settled(cancel_task.call(id), id)
    end
  end
end
