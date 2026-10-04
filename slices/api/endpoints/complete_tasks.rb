# frozen_string_literal: true

module API
  module Endpoints
    class CompleteTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["complete"]
      SCHEMA = Tasks::BULK

      def handle(ids:) = acted(ids)
    end
  end
end
