# frozen_string_literal: true

module Social
  module Queries
    class LinkableSocialPosts
      include Deps[social_post_repo: "repos.social_post_repo"]

      def matching(text, limit:) = social_post_repo.linkable(:social_posts, text:, limit:)

      def named(ids) = social_post_repo.linkable(:social_posts, ids:)
    end
  end
end
