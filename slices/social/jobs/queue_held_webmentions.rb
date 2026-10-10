# frozen_string_literal: true

module Social
  module Jobs
    class QueueHeldWebmentions < Blog::ScheduledJob
      include Deps[webmention_mutations: "repos.webmention_mutations", webmention_queries: "repos.webmention_queries"]

      def perform = webmention_queries.held.each { queue(it) }

      private

      def queue(held)
        VerifyWebmention.perform_async(held.source_url, held.target_url, held.post_id)
        webmention_mutations.release(held.id)
      end
    end
  end
end
