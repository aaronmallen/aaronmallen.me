# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Index < Action
        include Deps[
          inbox: "api.queries.inbox",
          post_queries: "posts.repos.post_queries",
          snoozed_inbox: "api.queries.snoozed_inbox",
        ]

        def handle(_request, response)
          response[:rows] = inbox.call
          response[:snoozed] = snoozed_inbox.call
          response[:slugs] = post_queries.summaries.to_h { [it.id, it.slug] }
        end
      end
    end
  end
end
