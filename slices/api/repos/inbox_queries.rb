# frozen_string_literal: true

module API
  module Repos
    class InboxQueries < Blog::DB::Repo
      COUNT = Sequel.function(:count).*
      LIMIT = 100

      include Deps[
        message_queries: "mail.repos.message_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def snoozed = snoozed_rows.sort_by { [it.at, it.kind, it.record.id] }

      def unseen(mail: true) = unseen_rows(mail).sort_by { [it.at, it.kind, it.record.id] }.last(LIMIT).reverse

      def unseen_counts
        unseen = {
          messages: message_queries.unread_threads,
          webmentions: webmention_queries.unseen_pending,
          tasks: task_source_queries.unseen,
        }

        connection.select(*unseen.map { |kind, found| found.dataset.unordered.select(COUNT).as(kind) }).first
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

      def unseen_rows(mail)
        [
          *(mail ? message_queries.unread(limit: LIMIT) : []).map { row(:message, it.received_at, it) },
          *webmention_queries.unseen(LIMIT).map { row(:webmention, it.received_at, it) },
          *task_source_queries.unseen_tasks(LIMIT).map { row(:task, it.created_at, it, it.source) },
        ]
      end
    end
  end
end
