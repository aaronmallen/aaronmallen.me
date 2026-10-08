# frozen_string_literal: true

module Posts
  module Operations
    class MovePost < Operation
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      include Deps[post_mutations: "repos.post_mutations", post_queries: "repos.post_queries"]

      def call(id, date, now: Time.now)
        day = step upcoming_day(date, now)

        transaction do
          post = step scheduled(post_mutations.by_id_for_update(id))
          post_mutations.update(post.id, published_at: step(moved_to_day(post.published_at, day, now)))
          post_queries.by_id(post.id)
        end
      end

      private

      def scheduled(post)
        found(post).bind { it.status == SCHEDULED ? Success(it) : Failure(:not_scheduled) }
      end
    end
  end
end
