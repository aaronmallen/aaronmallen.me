# frozen_string_literal: true

module Social
  module Queries
    class UnsentSocialPosts
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call = social_post_repo.drafts + social_post_repo.queued
    end
  end
end
