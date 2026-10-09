# frozen_string_literal: true

module Social
  module Jobs
    class SendDueSocialPosts < Blog::Job
      STALLED_AFTER = 15 * 60

      include Deps[
        list_target_accounts: "operations.list_target_accounts",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      sidekiq_options retry: false

      def perform
        now = Time.now

        social_post_queries.due_scheduled(now).each { queue(it, due_by: now, stale_before: now - STALLED_AFTER) }
      end

      private

      def queue(social_post, due_by:, stale_before:)
        list_target_accounts.call(social_post).each do |account|
          next unless social_post_mutations.claim_delivery(social_post.id, account, due_by:, stale_before:)

          DeliverSocialPost.perform_async(social_post.id, account.id)
        end
      end
    end
  end
end
