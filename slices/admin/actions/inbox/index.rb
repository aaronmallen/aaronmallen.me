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

        def handle(request, response)
          rows = inbox_queries.unseen
          response[:rows] = rows
          response[:count] = navigation(request).inbox_count
          response[:snoozed] = inbox_queries.snoozed
          response[:slugs] = slugs(rows)
          response[:tasks] = tasks(rows)
        end

        private

        def slugs(rows) = post_queries.slugs(rows.filter_map { it.record.post_id if it.kind == :webmention })

        def tasks(rows)
          record_link_queries.partner_ids(THREAD, rows.filter_map { it.record.id if it.kind == :message }, TASK)
        end
      end
    end
  end
end
