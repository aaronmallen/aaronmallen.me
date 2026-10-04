# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["delete"]
      SCHEMA = Tasks::BULK
      REPLY = Schema.object({ tasks: Schema.list(DeleteTask::REPLY) }).freeze

      def handle(ids:) = acted(ids)

      private

      def answered(_ids, tasks) = tasks.map { { id: it.id, title: it.title, deleted: true } }
    end
  end
end
