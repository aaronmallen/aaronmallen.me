# frozen_string_literal: true

module Posts
  module Operations
    class PublishPost < Blog::Operation
      include Deps[post_repo: "repos.post_repo"]

      def call(id, at: Time.now, only_if_due: false)
        post = step publish(id, at, only_if_due)
        post_repo.after_commit { Social::Jobs::SyndicatePost.once_published(post.id, at) }
        post_repo.after_commit { Social::Jobs::SendWebmentions.once_saved(post.id) }

        post
      end

      private

      def publish(id, at, only_if_due)
        post = only_if_due ? post_repo.publish_due(id, at:) : post_repo.publish(id, at:)

        post ? Success(post) : Failure(:not_due)
      end
    end
  end
end
