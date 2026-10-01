# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TaskEndpoint < Endpoint
      REPLY = Schema.widen(Serializers::Task::SCHEMA, comments: Schema.list(Serializers::TaskComment.reference)).freeze

      include Deps[task_by_id: "tasks.queries.task_by_id", task_comments: "tasks.queries.task_comments"]

      private

      def answered(id, **) = task_reply(task_by_id.call(id), **)

      def rejected(errors)
        complaints = Tasks.complaints(errors)

        Failure(Refusal.invalid(complaints, message: Tasks.summary(complaints)))
      end

      def settled(result, id)
        case result
        in Success(*) then answered(id)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Tasks::UNSAVED)
        end
      end

      def sprint_past = invalid(sprint_on: [Tasks::SPRINT_PAST])

      def task_reply(task, **extra)
        comments = serialized(Serializers::TaskComment, task_comments.call(task.id))

        Success(serialized(Serializers::Task, task).merge(comments:, **extra))
      end
    end
  end
end
