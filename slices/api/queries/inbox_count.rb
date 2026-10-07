# frozen_string_literal: true

module API
  module Queries
    class InboxCount
      include Deps[
        unread_message_count: "contact.queries.unread_message_count",
        unseen_task_count: "tasks.queries.unseen_task_count",
        unseen_webmention_count: "social.queries.unseen_webmention_count",
      ]

      def call = unread_message_count.call + unseen_webmention_count.call + unseen_task_count.call
    end
  end
end
