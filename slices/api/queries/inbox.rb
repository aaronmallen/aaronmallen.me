# frozen_string_literal: true

module API
  module Queries
    class Inbox
      Row = Data.define(:kind, :at, :record)

      include Deps[
        pending_webmentions: "social.queries.pending_webmentions",
        unread_messages: "contact.queries.unread_messages",
        unseen_tasks: "tasks.queries.unseen_tasks",
      ]

      def call = rows.sort_by { [it.at, it.kind, it.record.id] }.reverse

      private

      def rows
        [
          *unread_messages.call.map { Row.new(kind: :message, at: it.received_at, record: it) },
          *pending_webmentions.call.map { Row.new(kind: :webmention, at: it.received_at, record: it) },
          *unseen_tasks.call.map { Row.new(kind: :task, at: it.created_at, record: it) },
        ]
      end
    end
  end
end
