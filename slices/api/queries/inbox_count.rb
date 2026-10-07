# frozen_string_literal: true

module API
  module Queries
    class InboxCount
      include Deps[
        message_queries: "contact.repos.message_queries",
        unseen_task_count: "tasks.queries.unseen_task_count",
        unseen_webmention_count: "social.queries.unseen_webmention_count",
      ]

      def call = message_queries.unread_count + unseen_webmention_count.call + unseen_task_count.call
    end
  end
end
