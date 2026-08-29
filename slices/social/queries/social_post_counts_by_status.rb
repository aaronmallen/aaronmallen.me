# frozen_string_literal: true

module Social
  module Queries
    class SocialPostCountsByStatus
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call = social_post_repo.count_by_status
    end
  end
end
