# frozen_string_literal: true

module Posts
  module Operations
    class PublishDraft < Operation
      PUBLISH = Blog::Types::PostIntent["publish"]
      PUBLISHED = Blog::Types::PostStatus["published"]
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      include Deps[
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
        save_post: "operations.save_post",
      ]

      def call(id, now: Time.now)
        transaction do
          step unpublished(post_mutations.by_id_for_update(id))
          step save_post.call(form(post_queries.by_id(id)), id:, intent: PUBLISH, now:)
        end
      end

      private

      def form(post)
        fields = post.form

        post.status == SCHEDULED ? fields.merge(publish_at: Blog::Constants::EMPTY_STRING) : fields
      end

      def unpublished(post)
        found(post).bind { it.status == PUBLISHED ? Failure(:published) : Success(it) }
      end
    end
  end
end
