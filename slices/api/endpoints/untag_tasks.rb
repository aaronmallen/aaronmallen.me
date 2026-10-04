# frozen_string_literal: true

module API
  module Endpoints
    class UntagTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["untag"]
      SCHEMA = Schema.widen(Tasks::BULK, tag: Tasks::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
