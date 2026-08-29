# frozen_string_literal: true

module Social
  module Queries
    class SocialPostById
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id) = social_post_repo.by_id(id)
    end
  end
end
