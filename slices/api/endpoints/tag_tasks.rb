# frozen_string_literal: true

module API
  module Endpoints
    class TagTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["tag"]
      SCHEMA = Helpers::Schema.widen(Tasks::BULK, tag: Tasks::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
