# frozen_string_literal: true

module Shares
  module Operations
    class QueueShortLinkCheck < Blog::Operation
      include Deps[short_link_queries: "repos.short_link_queries"]

      def call(id)
        step found(short_link_queries.find(id))
        step(queued { Jobs::CheckShortLinkAgain.perform_async(id) })
      end
    end
  end
end
