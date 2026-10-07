# frozen_string_literal: true

module Social
  module Jobs
    class SyndicatePost < Blog::Job
      include Deps[post_queries: "posts.repos.post_queries", queue_syndication: "operations.queue_syndication"]

      sidekiq_options retry: 5

      def self.once_published(post_id, at) = perform_async(post_id, at.to_f)

      def perform(post_id, at)
        post = post_queries.by_id(post_id)

        queue_syndication.call(post, at: Time.at(at)) if post
      end
    end
  end
end
