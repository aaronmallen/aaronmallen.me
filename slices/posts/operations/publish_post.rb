# frozen_string_literal: true

module Posts
  module Operations
    class PublishPost < Blog::Operation
      include Deps[
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
        queue_follow_up: "operations.queue_follow_up",
      ]

      def call(id, at: Time.now, only_if_due: false)
        post = step publish(id, at, only_if_due)
        post_mutations.after_commit { queue_follow_up.call(post.id, QueueFollowUp::SYNDICATE_POST, at:) }
        post_mutations.after_commit { queue_follow_up.call(post.id, QueueFollowUp::SEND_WEBMENTIONS) }

        post
      end

      private

      def publish(id, at, only_if_due)
        published = only_if_due ? post_mutations.publish_due(id, at:) : post_mutations.publish(id, at:)

        published ? Success(post_queries.by_id(id)) : Failure(:not_due)
      end
    end
  end
end
