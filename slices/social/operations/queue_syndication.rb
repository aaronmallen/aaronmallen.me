# frozen_string_literal: true

module Social
  module Operations
    class QueueSyndication < Blog::Operation
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      include Deps[
        announcement: "posts.operations.compose_announcement",
        networks: "networks.all",
        save_social_post: "operations.save_social_post",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(post, at: Time.now)
        step wanted(post)
        step unqueued(post)
        targets = step targets(post)
        body = step body(post)

        queue(post, body, targets, at)
      end

      private

      def body(post)
        text = announcement.call(post)

        text.strip.empty? ? Failure(:nothing_to_say) : Success(text)
      end

      def queue(post, body, targets, at)
        step save_social_post.call(parts: [body], post_id: post.id, posted_at: at, status: SCHEDULED, targets:)
      end

      def targets(post)
        found = post.syndication_targets.to_a.select { networks.fetch(it).configured? }

        found.empty? ? Failure(:no_targets) : Success(found)
      end

      def unqueued(post)
        social_post_queries.any_for_post?(post.id) ? Failure(:already_queued) : Success(post)
      end

      def wanted(post) = post.syndication_enabled ? Success(post) : Failure(:not_syndicating)
    end
  end
end
