# frozen_string_literal: true

module Posts
  module Operations
    class QueueLinkCheck < Blog::Operation
      include Deps[post_queries: "repos.post_queries"]

      def call(post_id, url = nil)
        step found(post_queries.published_body(post_id))
        step(queued { Jobs::CheckPostLinksAgain.perform_async(*[post_id, url].compact) })
      end
    end
  end
end
