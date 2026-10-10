# frozen_string_literal: true

module Posts
  module Operations
    class PublishDraft < Blog::Operation
      PUBLISH = Blog::Types::PostIntent["publish"]

      include Deps[lock_unpublished_post: "operations.lock_unpublished_post", save_post: "operations.save_post"]

      def call(id, now: Time.now)
        transaction do
          post = step lock_unpublished_post.call(id)
          step save_post.call(form(post), id:, intent: PUBLISH, now:)
        end
      end

      private

      def form(post)
        fields = post.form

        post.scheduled? ? fields.merge(publish_at: Blog::Constants::EMPTY_STRING) : fields
      end
    end
  end
end
