# frozen_string_literal: true

module Admin
  module Operations
    class MakeMailTask < Blog::Operation
      ARCHIVE = Blog::Types::MessageBulkAction["archive"]
      TASK = Blog::Types::RecordKind["task"]
      THREAD = Blog::Types::RecordKind["mail_thread"]

      include Deps[
        capture_task: "tasks.operations.capture_task",
        change_thread: "mail.operations.change_thread",
        link_records: "links.operations.link_records",
        message_queries: "mail.repos.message_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      def call(id, params, filter:, archive:)
        task = transaction do
          step found(message_queries.by_id_for_update(id))
          step untasked(id)
          linked(id, step(capture_task.call(params, filter:)).last)
        end
        archive ? step(archived(id, task)) : task
      end

      private

      def archived(id, task) = change_thread.call(id, ARCHIVE).fmap { task }.alt_map { [:unarchived, task] }

      def linked(id, task)
        step link_records.call(TASK, task.id, { other_kind: THREAD, other_id: id })
        task
      end

      def untasked(id) = record_link_queries.partner_ids(THREAD, [id], TASK).empty? ? Success(id) : Failure(:tasked)
    end
  end
end
