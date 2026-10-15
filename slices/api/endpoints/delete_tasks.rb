# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["delete"]
      REPLY = Helpers::Schema.object({ tasks: Helpers::Schema.list(DeleteTask::REPLY) }).freeze

      private

      def answered(tasks) = tasks.map { { id: it.id, title: it.title, deleted: true } }
    end
  end
end
