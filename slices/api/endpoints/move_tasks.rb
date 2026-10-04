# frozen_string_literal: true

module API
  module Endpoints
    class MoveTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["move"]
      SCHEMA = Schema.widen(Tasks::BULK, list: MoveTask::SCHEMA.dig(:properties, :list)).freeze

      def handle(ids:, list:) = acted(ids, to: list)
    end
  end
end
