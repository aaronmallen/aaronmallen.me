# frozen_string_literal: true

module API
  module Endpoints
    class ReopenTask < TaskEndpoint
      SCHEMA = Tasks::BY_ID

      include Deps[reopen_task: "tasks.operations.reopen_task"]

      def handle(id:) = settled(reopen_task.call(id), id)
    end
  end
end
