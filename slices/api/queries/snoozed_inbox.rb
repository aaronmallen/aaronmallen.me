# frozen_string_literal: true

module API
  module Queries
    class SnoozedInbox
      include Deps[
        message_queries: "contact.repos.message_queries",
        snoozed_tasks: "tasks.queries.snoozed_tasks",
        snoozed_webmentions: "social.queries.snoozed_webmentions",
      ]

      def call = rows.sort_by { [it.at, it.kind, it.record.id] }

      private

      def rows
        [
          *message_queries.snoozed.map { Inbox::Row.new(kind: :message, at: it.snoozed_until, record: it) },
          *snoozed_webmentions.call.map { Inbox::Row.new(kind: :webmention, at: it.snoozed_until, record: it) },
          *snoozed_tasks.call.map { Inbox::Row.new(kind: :task, at: it.source.snoozed_until, record: it) },
        ]
      end
    end
  end
end
