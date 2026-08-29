# frozen_string_literal: true

module Social
  module Jobs
    class SendDueSocialPosts < Blog::Job
      STALLED_AFTER = 15 * 60

      include Deps[social_post_repo: "repos.social_post_repo"]

      sidekiq_options retry: false

      def perform
        now = Time.now

        social_post_repo.due_scheduled(now).each { queue(it, stale_before: now - STALLED_AFTER) }
      end

      private

      def queue(social_post, stale_before:)
        social_post.targets.each do |network|
          next unless social_post_repo.claim_delivery(social_post.id, network, stale_before:)

          DeliverSocialPost.perform_async(social_post.id, network)
        end
      end
    end
  end
end
