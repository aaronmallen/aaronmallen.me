# frozen_string_literal: true

module API
  module Queries
    class InboxCount
      include Deps[
        message_queries: "contact.repos.message_queries",
        task_source_queries: "tasks.repos.task_source_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call = message_queries.unread_count + webmention_queries.unseen_count + task_source_queries.unseen_task_count
    end
  end
end
