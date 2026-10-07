# frozen_string_literal: true

module API
  module Queries
    class Inbox
      Row = Data.define(:kind, :at, :record)

      include Deps[
        message_queries: "contact.repos.message_queries",
        unseen_tasks: "tasks.queries.unseen_tasks",
        unseen_webmentions: "social.queries.unseen_webmentions",
      ]

      def call = rows.sort_by { [it.at, it.kind, it.record.id] }.reverse

      private

      def row(kind, arrived_at, record, snoozable = record)
        Row.new(kind:, at: [arrived_at, snoozable.snoozed_until].compact.max, record:)
      end

      def rows
        [
          *message_queries.unread.map { row(:message, it.received_at, it) },
          *unseen_webmentions.call.map { row(:webmention, it.received_at, it) },
          *unseen_tasks.call.map { row(:task, it.created_at, it, it.source) },
        ]
      end
    end
  end
end
