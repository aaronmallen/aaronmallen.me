# frozen_string_literal: true

module Social
  module Queries
    class UnsentSocialPosts
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(page) = social_post_repo.unsent_page(page)
    end
  end
end
