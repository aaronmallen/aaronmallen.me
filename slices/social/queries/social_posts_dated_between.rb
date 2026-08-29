# frozen_string_literal: true

module Social
  module Queries
    class SocialPostsDatedBetween
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(from:, to:) = social_post_repo.dated_between(from:, to:)
    end
  end
end
