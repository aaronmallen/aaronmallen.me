# frozen_string_literal: true

module Posts
  module Operations
    class MovePost < Blog::Operation
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      include Blog::DayMove
      include Deps[post_repo: "repos.post_repo"]

      def call(id, date, now: Time.now)
        day = step ahead(date, now)

        transaction do
          post = step scheduled(post_repo.by_id_for_update(id))
          post_repo.update(post.id, published_at: step(moved(post.published_at, day, now)))
          post_repo.by_id(post.id)
        end
      end

      private

      def scheduled(post)
        found(post).bind { it.status == SCHEDULED ? Success(it) : Failure(:not_scheduled) }
      end
    end
  end
end
