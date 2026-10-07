# frozen_string_literal: true

module Posts
  module Jobs
    class QueueHeldFollowUps < Blog::Job
      include Deps[
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
        queue_follow_up: "operations.queue_follow_up",
      ]

      sidekiq_options retry: false

      def perform = post_queries.held_follow_ups.each { queue(it) }

      private

      def queue(held)
        queue_follow_up.queue(held.post_id, held.follow_up, held.requested_at)
        post_mutations.release_follow_up(held.id)
      end
    end
  end
end
