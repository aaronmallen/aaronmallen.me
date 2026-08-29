# frozen_string_literal: true

module Social
  module Operations
    class DeleteSocialPost < Blog::Operation
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id)
        step removed(id, social_post_repo.delete_unposted(id))
      end

      private

      def removed(id, count)
        return Success(id) if count.positive?

        social_post_repo.claimed?(id) ? Failure(:already_posted) : Failure(:not_found)
      end
    end
  end
end
