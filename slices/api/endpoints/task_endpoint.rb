# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TaskEndpoint < Endpoint
      CLOSED = "task %s is already done or canceled"
      KIND = "task"

      REPLY = Schema.widen(
        Serializers::Task::SCHEMA,
        comments: Schema.list(Serializers::TaskComment.reference),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_links: "links.queries.record_links",
        task_by_id: "tasks.queries.task_by_id",
        task_comments: "tasks.queries.task_comments",
      ]

      private

      def answered(id, **) = task_reply(task_by_id.call(id), **)

      def placed(result, id)
        case result
        in Failure(:closed) then invalid(id: [format(CLOSED, id)])
        in Failure(:past | :invalid) then sprint_past
        else settled(result, id)
        end
      end

      def rejected(errors)
        complaints = Wording.complaints(errors, Tasks::COMPLAINTS)

        Failure(Refusal.invalid(complaints, message: Wording.summary(complaints)))
      end

      def settled(result, id)
        case result
        in Success(*) then answered(id)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Wording::UNSAVED)
        end
      end

      def sprint_past = invalid(sprint_on: [Tasks::SPRINT_PAST])

      def task_reply(task, **extra)
        comments = serialized(Serializers::TaskComment, task_comments.call(task.id))

        record_links = linked(KIND, task.id)

        Success(serialized(Serializers::Task, task).merge(comments:, record_links:, **extra))
      end
    end
  end
end
