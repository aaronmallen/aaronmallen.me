# frozen_string_literal: true

module Posts
  module Jobs
    class PublishDuePosts < Blog::Job
      include Deps[
        honeybadger: "honeybadger.agent", post_repo: "repos.post_repo", publish_post: "operations.publish_post",
      ]

      sidekiq_options retry: false

      def perform
        now = Time.now
        first, *rest = post_repo.due_scheduled(now).filter_map { publish(it, now) }
        return unless first

        rest.each { honeybadger.notify(it) }
        raise first
      end

      private

      def publish(post, now)
        publish_post.call(post.id, at: now, only_if_due: true)
        nil
      rescue StandardError => e
        e
      end
    end
  end
end
