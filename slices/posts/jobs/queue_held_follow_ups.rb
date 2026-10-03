# frozen_string_literal: true

module Posts
  module Jobs
    class QueueHeldFollowUps < Blog::Job
      include Deps[post_repo: "repos.post_repo", queue_follow_up: "operations.queue_follow_up"]

      sidekiq_options retry: false

      def perform = post_repo.held_follow_ups.each { queue(it) }

      private

      def queue(held)
        queue_follow_up.queue(held.post_id, held.follow_up, held.requested_at)
        post_repo.release_follow_up(held.id)
      end
    end
  end
end
