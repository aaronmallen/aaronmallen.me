# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Index < Action
        include Deps[
          inbox_queries: "api.repos.inbox_queries",
          post_queries: "posts.repos.post_queries",
        ]

        def handle(_request, response)
          response[:rows] = inbox_queries.unseen
          response[:snoozed] = inbox_queries.snoozed
          response[:slugs] = post_queries.summaries.to_h { [it.id, it.slug] }
        end
      end
    end
  end
end
