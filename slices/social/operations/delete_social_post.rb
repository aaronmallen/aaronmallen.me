# frozen_string_literal: true

module Social
  module Operations
    class DeleteSocialPost < Operation
      include Deps[
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(id)
        step removed(id, social_post_mutations.delete_unposted(id))
      end

      private

      def removed(id, count)
        return Success(id) if count.positive?

        social_post_queries.claimed?(id) ? Failure(:already_posted) : Failure(:not_found)
      end
    end
  end
end
