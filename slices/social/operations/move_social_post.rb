# frozen_string_literal: true

module Social
  module Operations
    class MoveSocialPost < Blog::Operation
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      include Blog::DayMove
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id, date, now: Time.now)
        day = step ahead(date, now)

        transaction do
          social_post = step scheduled(id, social_post_repo.locked_editable(id))
          social_post_repo.update(social_post.id, posted_at: step(moved(social_post.posted_at, day)))
          social_post_repo.by_id(social_post.id)
        end
      end

      private

      def scheduled(id, social_post)
        return Success(social_post) if social_post&.status == SCHEDULED && social_post.posted_at

        social_post_repo.by_id(id) ? Failure(:not_scheduled) : Failure(:not_found)
      end
    end
  end
end
