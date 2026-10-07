# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TaskEndpoint < Endpoint
      KIND = "task"

      REPLY = Schema.widen(
        Serializers::Task::SCHEMA,
        comments: Schema.list(Serializers::TaskComment.reference),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_links: "links.queries.record_links",
        task_comment_queries: "tasks.repos.task_comment_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      private

      def answered(id, **) = task_reply(task_queries.detailed(id), **)

      def placed(result, id)
        case result
        in Failure(:past | :invalid) then sprint_past
        else settled(result, id)
        end
      end

      def settled(result, id)
        case result
        in Success(*) then answered(id)
        in Failure(:not_found) then not_found(Wording.missing("task", id))
        in Failure(:closed) then invalid(id: [format(Tasks::CLOSED, id)])
        else failed(Wording::UNSAVED)
        end
      end

      def sprint_past = invalid(sprint_on: [Tasks::SPRINT_PAST])

      def task_reply(task, **extra)
        comments = serialized(Serializers::TaskComment, task_comment_queries.for_task(task.id))

        record_links = linked(KIND, task.id)

        Success(serialized(Serializers::Task, task).merge(comments:, record_links:, **extra))
      end
    end
  end
end
