# frozen_string_literal: true

module Social
  module Operations
    class RefreshSocialEngagement < Operation
      WINDOW = 30 * 24 * 60 * 60

      include Deps[
        "services.repos.connection_queries",
        networks: "networks.all",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(now: Time.now)
        social_post_queries.posted_since(now - WINDOW).sum { refresh(it) }
      end

      private

      def client(delivery)
        network = networks.fetch(delivery.network)
        account = delivery.connection_id && connection_queries.by_id(delivery.connection_id)

        account ? network.for(account) : network
      end

      def engagement(delivery)
        remote_id = delivery.remote_ids.to_a.first
        return nil unless remote_id

        client(delivery).engagement(remote_id)
      rescue Social::Error
        nil
      end

      def refresh(social_post) = social_post.deliveries.count { refreshed?(it) }

      def refreshed?(delivery)
        counts = engagement(delivery)
        return false unless counts

        social_post_mutations.record_engagement(
          delivery.id,
          like_count: counts.like_count, reply_count: counts.reply_count, repost_count: counts.repost_count,
        )

        true
      end
    end
  end
end
