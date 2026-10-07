# frozen_string_literal: true

module API
  module Queries
    class Inbox
      Row = Data.define(:kind, :at, :record)

      include Deps[
        message_queries: "contact.repos.message_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call = rows.sort_by { [it.at, it.kind, it.record.id] }.reverse

      private

      def row(kind, arrived_at, record, snoozable = record)
        Row.new(kind:, at: [arrived_at, snoozable.snoozed_until].compact.max, record:)
      end

      def rows
        [
          *message_queries.unread.map { row(:message, it.received_at, it) },
          *webmention_queries.unseen.map { row(:webmention, it.received_at, it) },
          *task_source_queries.unseen_tasks.map { row(:task, it.created_at, it, it.source) },
        ]
      end
    end
  end
end
