# frozen_string_literal: true

module API
  module Queries
    class InboxCount
      UNREAD = Blog::Types::MessageStatus["unread"]

      include Deps[
        count_messages_with_status: "contact.queries.count_with_status",
        pending_webmention_count: "social.queries.pending_webmention_count",
        unseen_task_count: "tasks.queries.unseen_task_count",
      ]

      def call = count_messages_with_status.call(UNREAD) + pending_webmention_count.call + unseen_task_count.call
    end
  end
end
