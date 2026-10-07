# frozen_string_literal: true

module Posts
  module Operations
    class PublishDraft < Operation
      PUBLISH = Blog::Types::PostIntent["publish"]
      PUBLISHED = Blog::Types::PostStatus["published"]
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      include Deps[post_repo: "repos.post_repo", save_post: "operations.save_post"]

      def call(id, now: Time.now)
        transaction do
          step unpublished(post_repo.by_id_for_update(id))
          step save_post.call(form(post_repo.by_id(id)), id:, intent: PUBLISH, now:)
        end
      end

      private

      def form(post)
        fields = PostForm.call(post)

        post.status == SCHEDULED ? fields.merge(publish_at: Blog::Constants::EMPTY_STRING) : fields
      end

      def unpublished(post)
        found(post).bind { it.status == PUBLISHED ? Failure(:published) : Success(it) }
      end
    end
  end
end
