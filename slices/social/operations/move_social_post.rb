# frozen_string_literal: true

module Social
  module Operations
    class MoveSocialPost < Operation
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      include Deps[
        lock_editable_social_post: "operations.lock_editable_social_post",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(id, date, now: Time.now)
        day = step upcoming_day(date, now)

        transaction do
          social_post = step scheduled(id, lock_editable_social_post.call(id))
          social_post_mutations.update(social_post.id, posted_at: step(moved_to_day(social_post.posted_at, day, now)))
          social_post_queries.by_id(social_post.id)
        end
      end

      private

      def scheduled(id, social_post)
        return Success(social_post) if social_post&.status == SCHEDULED && social_post.posted_at

        social_post_queries.by_id(id) ? Failure(:not_scheduled) : Failure(:not_found)
      end
    end
  end
end
