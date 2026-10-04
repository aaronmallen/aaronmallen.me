# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Index < Action
        include Deps[inbox: "api.queries.inbox", post_summaries: "posts.queries.summaries"]

        def handle(_request, response)
          response[:rows] = inbox.call
          response[:slugs] = post_summaries.call.to_h { [it.id, it.slug] }
        end
      end
    end
  end
end
