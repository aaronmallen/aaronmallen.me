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

      BRIEF = Serializers::Task::SCHEMA.fetch(:properties).slice(:id, :label, :status).freeze

      include Deps[
        record_link_queries: "links.repos.record_link_queries",
        task_comment_queries: "tasks.repos.task_comment_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      private

      def answered(id, **) = task_reply(task_queries.detailed(id), **)

      def brief(id, shown)
        task = task_queries.detailed(id)
        fields = serialized(Serializers::Task, task).transform_keys(&:to_sym).slice(:id, :label, :status, *shown)
        note = ({ note: Helpers::Untrusted.call(task.note) } if shown.include?(:note))

        Success(fields.merge(note || {}))
      end

      def placed(result, id, shown = nil)
        case result
          in Failure(:past) then sprint_past
          in Failure(:invalid) then sprint_unread
          else settled(result, id, shown)
        end
      end

      def settled(result, id, shown = nil)
        case result
          in Success(*) then shown ? brief(id, shown) : answered(id)
          in Failure(:not_found) then missing("task", id)
          in Failure(:closed) then invalid(id: [format(Tasks::CLOSED, id)])
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
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
