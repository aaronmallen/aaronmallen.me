# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Index < Action
        TASK = Blog::Types::RecordKind["task"]
        THREAD = Blog::Types::RecordKind["mail_thread"]

        include Deps[
          inbox_queries: "api.repos.inbox_queries",
          post_queries: "posts.repos.post_queries",
          record_link_queries: "links.repos.record_link_queries",
        ]

        def handle(_request, response)
          rows = inbox_queries.unseen
          response[:rows] = rows
          response[:snoozed] = inbox_queries.snoozed
          response[:slugs] = post_queries.summaries.to_h { [it.id, it.slug] }
          response[:tasks] = record_link_queries.partner_ids(THREAD, message_ids(rows), TASK)
        end

        private

        def message_ids(rows) = rows.filter_map { it.record.id if it.kind == :message }
      end
    end
  end
end
