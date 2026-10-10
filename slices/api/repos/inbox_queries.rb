# frozen_string_literal: true

module API
  module Repos
    class InboxQueries < DB::Repo
      include Deps[
        message_queries: "contact.repos.message_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def snoozed = snoozed_rows.sort_by { [it.at, it.kind, it.record.id] }

      def unseen = unseen_rows.sort_by { [it.at, it.kind, it.record.id] }.reverse

      def unseen_count
        message_queries.unread_count + webmention_queries.unseen_count + task_source_queries.unseen_task_count
      end

      private

      def row(kind, arrived_at, record, snoozable = record)
        Structs::InboxRow.new(kind:, at: [arrived_at, snoozable.snoozed_until].compact.max, record:)
      end

      def snoozed_row(kind, record, snoozable = record)
        Structs::InboxRow.new(kind:, at: snoozable.snoozed_until, record:)
      end

      def snoozed_rows
        [
          *message_queries.snoozed.map { snoozed_row(:message, it) },
          *webmention_queries.snoozed.map { snoozed_row(:webmention, it) },
          *task_source_queries.snoozed_tasks.map { snoozed_row(:task, it, it.source) },
        ]
      end

      def unseen_rows
        [
          *message_queries.unread.map { row(:message, it.received_at, it) },
          *webmention_queries.unseen.map { row(:webmention, it.received_at, it) },
          *task_source_queries.unseen_tasks.map { row(:task, it.created_at, it, it.source) },
        ]
      end
    end
  end
end
