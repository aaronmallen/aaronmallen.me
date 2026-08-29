# frozen_string_literal: true

module Suggestions
  module Queries
    class OpenCountsForSocialPosts
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(social_post_ids) = suggestion_repo.open_counts_for_social_posts(social_post_ids)
    end
  end
end
