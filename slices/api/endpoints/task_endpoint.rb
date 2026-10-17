# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TaskEndpoint < Endpoint
      KIND = "task"

      REPLY = Helpers::Schema.widen(
        Serializers::Task::SCHEMA,
        note: Helpers::Schema::STRING,
        comments: Helpers::Schema.list(Serializers::TaskComment.reference),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_link_queries: "links.repos.record_link_queries",
        task_comment_queries: "tasks.repos.task_comment_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      private

      def answered(id, **) = task_reply(task_queries.detailed(id), **)

      def placed(result, id)
        case result
          in Failure(:past) then sprint_past
          in Failure(:invalid) then sprint_unread
          else settled(result, id)
        end
      end

      def settled(result, id)
        case result
          in Success(*) then answered(id)
          in Failure(:not_found) then missing("task", id)
          in Failure(:closed) then invalid(id: [format(Tasks::CLOSED, id)])
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      def sprint_past = invalid(sprint_on: [Tasks::SPRINT_PAST])

      def sprint_unread = invalid(sprint_on: [Tasks::SPRINT_DAY])

      def task_reply(task, **extra)
        comments = serialized(Serializers::TaskComment, task_comment_queries.for_task(task.id),
                              owner: settings.owner_name)

        note = Helpers::Untrusted.call(task.note)

        Success(serialized(Serializers::Task, task).merge(note:, comments:, record_links: links_for(task.id), **extra))
      end
    end
  end
end
