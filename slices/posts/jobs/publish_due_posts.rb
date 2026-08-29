# frozen_string_literal: true

module Posts
  module Jobs
    class PublishDuePosts < Blog::Job
      include Deps[post_repo: "repos.post_repo", publish_post: "operations.publish_post"]

      sidekiq_options retry: false

      def perform
        now = Time.now
        post_repo.due_scheduled(now).each { publish_post.call(it.id, at: now, only_if_due: true) }
      end
    end
  end
end
