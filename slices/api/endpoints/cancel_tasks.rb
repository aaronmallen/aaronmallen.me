# frozen_string_literal: true

module API
  module Endpoints
    class CancelTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["cancel"]
      SCHEMA = Tasks::BULK

      def handle(ids:) = acted(ids)
    end
  end
end
