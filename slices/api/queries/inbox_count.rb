# frozen_string_literal: true

module API
  module Queries
    class InboxCount
      include Deps[
        message_queries: "contact.repos.message_queries",
        unseen_task_count: "tasks.queries.unseen_task_count",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call = message_queries.unread_count + webmention_queries.unseen_count + unseen_task_count.call
    end
  end
end
