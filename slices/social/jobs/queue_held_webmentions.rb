# frozen_string_literal: true

module Social
  module Jobs
    class QueueHeldWebmentions < Blog::Job
      include Deps[webmention_repo: "repos.webmention_repo"]

      sidekiq_options retry: false

      def perform = webmention_repo.held.each { queue(it) }

      private

      def queue(held)
        VerifyWebmention.perform_async(held.source_url, held.target_url, held.post_id)
        webmention_repo.release(held.id)
      end
    end
  end
end
