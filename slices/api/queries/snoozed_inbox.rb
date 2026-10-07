# frozen_string_literal: true

module API
  module Queries
    class SnoozedInbox
      include Deps[
        message_queries: "contact.repos.message_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call = rows.sort_by { [it.at, it.kind, it.record.id] }

      private

      def rows
        [
          *message_queries.snoozed.map { Inbox::Row.new(kind: :message, at: it.snoozed_until, record: it) },
          *webmention_queries.snoozed.map { Inbox::Row.new(kind: :webmention, at: it.snoozed_until, record: it) },
          *task_source_queries.snoozed_tasks.map do |task|
            Inbox::Row.new(kind: :task, at: task.source.snoozed_until, record: task)
          end,
        ]
      end
    end
  end
end
